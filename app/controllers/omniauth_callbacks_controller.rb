class OmniauthCallbacksController < ApplicationController
  before_action :require_login

  def facebook
    auth = request.env["omniauth.auth"]

    if User.where(provider: auth.provider, uid: auth.uid).where.not(id: current_user.id).exists?
      return redirect_to profile_path, alert: "บัญชี Facebook นี้ถูกเชื่อมต่อกับผู้ใช้อื่นในระบบแล้ว"
    end

    current_user.assign_attributes(
      provider: auth.provider,
      uid: auth.uid,
      image: auth.info.image,
      oauth_token: auth.credentials.token,
      oauth_expires_at: auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil,
    )

    if current_user.changed?
      current_user.save!
      # Sync managed pages to store Page Access Tokens for later webhook processing
      begin
        pages = FacebookApiService.new(current_user.oauth_token).get_pages
        if pages.is_a?(Hash) && pages["data"].is_a?(Array)
          pages["data"].each do |p|
            next unless p["id"].present? && p["access_token"].present?
            Page.find_or_initialize_by(page_id: p["id"]).tap do |page|
              page.user = current_user
              page.name = p["name"]
              page.access_token = p["access_token"]
              page.save!
            end
          end
        end
      rescue => e
        Rails.logger.warn "Sync pages failed: #{e.message}"
      end
      return redirect_to profile_path, notice: "เชื่อมต่อบัญชี Facebook สำเร็จ!"
    else
      return redirect_to profile_path, notice: "บัญชีของคุณเชื่อมต่อกับ Facebook อยู่แล้ว"
    end
  rescue => e
    return redirect_to profile_path, alert: "เกิดข้อผิดพลาดในการเชื่อมต่อกับ Facebook: #{e.message}"
  end

  def failure
    error_message = case params[:message]
      when "access_denied"
        "คุณได้ยกเลิกการเชื่อมบัญชีด้วย Facebook 🚫"
      when "invalid_credentials"
        "ข้อมูลการเชื่อมบัญชีไม่ถูกต้อง ❌"
      when "timeout"
        "การเชื่อมต่อหมดเวลา ⏰"
      else
        "ไม่สามารถเชื่อมบัญชีด้วย Facebook ได้ในขณะนี้ 😔 กรุณาลองใหม่อีกครั้ง"
      end

    redirect_to profile_path, alert: error_message
  end

  private

  def require_login
    unless user_signed_in?
      redirect_to login_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end
end
