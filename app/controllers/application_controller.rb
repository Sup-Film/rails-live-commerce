class ApplicationController < ActionController::Base
  helper_method :current_user, :user_signed_in?

  # Method สำหรับตรวจสอบว่าผู้ใช้ล็อกอินอยู่หรือไม่
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # ถ้า @current_user มีค่า (ไม่เป็น nil) จะ Return true ถ้าไม่มีก็จะ Return false
  def user_signed_in?
    !!current_user
  end
end
