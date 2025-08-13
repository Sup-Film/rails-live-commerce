class OmniauthCallbacksController < ApplicationController
  before_action :require_login

  def facebook
    auth = request.env["omniauth.auth"]

    if User.exists?(provider: auth.provider, uid: auth.uid)
      return redirect_to profile_path, alert: "บัญชี Facebook นี้ถูกเชื่อมต่อกับผู้ใช้อื่นในระบบแล้ว"
    end

    current_user.update!(
      provider: auth.provider,
      uid: auth.uid,
      image: auth.info.image,
      oauth_token: auth.credentials.token,
      oauth_expires_at: auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil,
    )

    if current_user.changed?
      current_user.save!
    else
      redirect_to profile_path, notice: "บัญชีของคุณเชื่อมต่อกับ Facebook อยู่แล้ว"
    end

    redirect_to profile_path, notice: "เชื่อมต่อบัญชี Facebook สำเร็จ!"
  rescue => e
    redirect_to profile_path, alert: "เกิดข้อผิดพลาดในการเชื่อมต่อกับ Facebook: #{e.message}"
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
