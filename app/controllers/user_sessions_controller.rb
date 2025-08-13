class UserSessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:session][:email])

    if user&.authenticate(params[:session][:password])
      log_in(user)
      redirect_to root_path, notice: "เข้าสู่ระบบสำเร็จ! ยินดีต้อนรับ #{user.name} 🎉"
    else
      flash.now[:alert] = "อีเมลหรือรหัสผ่านไม่ถูกต้อง ❌"
      render :new, status: :unprocessable_entity
    end
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

  private

  def log_in(user)
    reset_session
    session[:user_id] = user.id
  end
end
