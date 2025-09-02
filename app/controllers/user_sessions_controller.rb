class UserSessionsController < ApplicationController

  def new
    if cookies[:flash_alert] == "too_many_attempts"
      flash.now[:alert] = "คุณกรอกผิดเกินจำนวนครั้งที่กำหนด กรุณารอสักครู่ก่อนลองใหม่อีกครั้ง"
      cookies.delete(:flash_alert)
    end
  end

  def create
    email = login_params[:email].to_s.downcase.strip
    user = User.find_by(email: email)
    if user&.authenticate(login_params[:password])
      log_in(user)
      redirect_to root_path, notice: "เข้าสู่ระบบสำเร็จ! ยินดีต้อนรับ #{user.name} 🎉"
    else
      flash.now[:alert] = "อีเมลหรือรหัสผ่านไม่ถูกต้อง ❌"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    user_name = current_user&.name
    reset_session

    if user_name
      redirect_to root_path, notice: "ออกจากระบบเรียบร้อยแล้ว! แล้วพบกันใหม่ #{user_name} 👋"
    else
      redirect_to root_path, notice: "ออกจากระบบเรียบร้อยแล้ว! 👋"
    end
  end

  private

  def log_in(user)
    reset_session
    session[:user_id] = user.id
  end

  def login_params
    params.require(:session).permit(:email, :password)
  end
end
