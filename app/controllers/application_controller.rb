class ApplicationController < ActionController::Base
  helper_method :current_user, :user_signed_in?, :check_active_subscription?
  before_action :enforce_session_timeout

  # จัดการ OmniAuth errors
  rescue_from OmniAuth::Strategies::Facebook::NoAuthorizationCodeError do |exception|
    redirect_to root_path, alert: "คุณได้ยกเลิกการเชื่อมต่อ Facebook 🚫 กรุณาลองใหม่อีกครั้ง"
  end

  rescue_from OmniAuth::Error do |exception|
    redirect_to root_path, alert: "เกิดข้อผิดพลาดในการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง ⚠️"
  end

  # Method สำหรับตรวจสอบว่าผู้ใช้ล็อกอินอยู่หรือไม่
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # ถ้า @current_user มีค่า (ไม่เป็น nil) จะ Return true ถ้าไม่มีก็จะ Return false
  def user_signed_in?
    !!current_user
  end

  def check_active_subscription?
    current_user&.current_subscription&.active?
  end

  private

  # บังคับให้ session หมดอายุเมื่อไม่มีการใช้งาน 30 นาที
  def enforce_session_timeout
    return unless user_signed_in?

    now = Time.current.to_i
    last_seen = session[:last_seen_at].to_i

    if last_seen.positive? && (now - last_seen) > 30.minutes.to_i
      reset_session
      redirect_to login_path, alert: "เซสชันหมดเวลา กรุณาเข้าสู่ระบบใหม่" and return
    end

    session[:last_seen_at] = now
  end
end
