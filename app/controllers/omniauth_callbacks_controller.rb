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
          
          # Sync Instagram Business Accounts
          sync_instagram_accounts(pages["data"])
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

  def sync_instagram_accounts(pages_data)
    pages_data.each do |page|
      next unless page["access_token"].present?
      
      begin
        # Get Instagram Business Account connected to this page
        ig_response = FacebookApiService.new(page["access_token"]).get_instagram_account(page["id"])
        
        if ig_response&.dig("instagram_business_account", "id")
          ig_account_id = ig_response["instagram_business_account"]["id"]
          ig_username = ig_response.dig("instagram_business_account", "username")
          
          # อัปเดต User
          current_user.update!(
            instagram_user_id: ig_account_id,
            instagram_username: ig_username
          )
          
          # อัปเดต Page ที่เชื่อมกับ IG account นี้
          page_record = Page.find_by(page_id: page["id"])
          if page_record
            page_record.update!(instagram_business_account_id: ig_account_id)
          end
          
          break # เอาแค่ IG account แรกที่เจอ
        end
      rescue => e
        Rails.logger.warn "Failed to sync Instagram for page #{page['id']}: #{e.message}"
      end
    end
  end

  def require_login
    unless user_signed_in?
      redirect_to login_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end
end
