class UserSessionsController < ApplicationController
  # ยกเว้นการตรวจสอบ CSRF สำหรับ callback จาก OmniAuth
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    auth = request.env["omniauth.auth"]
    access_token = auth.credentials.token
    email = auth.info.email

    if auth.nil?
      redirect_to root_path, alert: "Authentication failed!"
      return
    end

    begin
      user = User.from_omniauth(auth)
      session[:user_id] = user.id

      redirect_to root_path, notice: "Signed in successfully as #{user.name}!"
    rescue => e
      logger.error "Authentication Error: #{e.message}"
      redirect_to root_path, alert: "Authentication error: #{e.message}"
    end
  end

  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Signed out!"
  end
end
