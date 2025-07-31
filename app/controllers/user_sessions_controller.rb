class UserSessionsController < ApplicationController
  # ยกเว้นการตรวจสอบ CSRF สำหรับ callback จาก OmniAuth
  skip_before_action :verify_authenticity_token, only: [:create]

  def new
  end

  def create
    if auth = request.env["omniauth.auth"]
      handle_omniauth_login(auth)
    else
      handle_form_login
    end
  end

  def failure
    # แสดงข้อความที่เป็นมิตรขึ้นตาม error type
    error_message = case params[:message]
      when "access_denied"
        "คุณได้ยกเลิกการเข้าสู่ระบบด้วย Facebook 🚫"
      when "invalid_credentials"
        "ข้อมูลการเข้าสู่ระบบไม่ถูกต้อง ❌"
      when "timeout"
        "การเชื่อมต่อหมดเวลา ⏰"
      else
        "ไม่สามารถเข้าสู่ระบบด้วย Facebook ได้ในขณะนี้ 😔 กรุณาลองใหม่อีกครั้ง"
      end

    redirect_to root_path, alert: error_message
  end

  def destroy
    user_name = current_user&.name
    session[:user_id] = nil

    if user_name
      redirect_to root_path, notice: "ออกจากระบบเรียบร้อยแล้ว! แล้วพบกันใหม่ #{user_name} 👋"
    else
      redirect_to root_path, notice: "ออกจากระบบเรียบร้อยแล้ว! 👋"
    end
  end

  def handle_form_login
    # byebug
    user = User.find_by(email: params[:session][:email])

    if user&.authenticate(params[:session][:password])
      log_in(user)
      redirect_to root_path, notice: "เข้าสู่ระบบสำเร็จ! ยินดีต้อนรับ #{user.name} 🎉"
    else
      flash.now[:alert] = "อีเมลหรือรหัสผ่านไม่ถูกต้อง ❌"
      render :new, status: :unprocessable_entity
    end
  end

  def handle_omniauth_login(auth)
    unless auth.credentials&.token
      redirect_to root_path, alert: "ไม่ได้รับสิทธิ์การเข้าถึงจาก Facebook 🔒"
      return
    end

    begin
      user = User.from_omniauth(auth)
      log_in(user)

      redirect_to root_path, notice: "เข้าสู่ระบบสำเร็จ! ยินดีต้อนรับ #{user.name} 🎉"
    rescue => e
      logger.error "Authentication Error: #{e.message}"
      logger.error e.backtrace.join("\n")
      redirect_to root_path, alert: "เกิดข้อผิดพลาดในการเข้าสู่ระบบ กรุณาลองใหม่อีกครั้ง ⚠️"
    end
  end

  private

  def log_in(user)
    session[:user_id] = user.id
  end
end
