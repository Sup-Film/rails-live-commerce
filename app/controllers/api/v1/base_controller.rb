class Api::V1::BaseController < ActionController::API
  include ActionController::Cookies
  
  before_action :authenticate_user!
  
  private
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  
  def authenticate_user!
    unless current_user
      render json: { 
        message: "กรุณาเข้าสู่ระบบก่อนใช้งาน", 
        error: "unauthorized" 
      }, status: :unauthorized
    end
  end
  
  def user_signed_in?
    !!current_user
  end
end
