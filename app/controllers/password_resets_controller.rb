class PasswordResetsController < ApplicationController
  before_action :find_user_by_token, only: [:show, :update]
  before_action :check_token_expiration, only: [:show, :update]

  # GET /password_resets/new - แสดงฟอร์มกรอกอีเมล
  def new
  end

  # POST /password_resets - ส่งอีเมลรีเซ็ตรหัสผ่าน (ตอบแบบ generic เพื่อกัน email enumeration)
  def create
    email = password_reset_params[:email].to_s.downcase.strip
    if email.present? && (user = User.find_by(email: email))
      user.generate_password_reset_token!
      PasswordResetMailer.reset_email(user).deliver_now
    end
    redirect_to login_path, notice: "ถ้ามีบัญชี เราได้ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลแล้ว"
  rescue => e
    Rails.logger.error "Password reset error: #{e.message}"
    redirect_to new_password_reset_path, alert: "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง"
  end

  # GET /password_resets/:token - แสดงฟอร์มตั้งรหัสผ่านใหม่
  def show
  end

  # PATCH /password_resets/:token - อัพเดทรหัสผ่านใหม่
  def update
    if params[:password].present? && params[:password] == params[:password_confirmation]
      if params[:password].length >= 6
        @user.reset_password!(params[:password])
        flash[:notice] = "เปลี่ยนรหัสผ่านสำเร็จ กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่"
        redirect_to login_path
      else
        flash.now[:alert] = "รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร"
        render :show
      end
    else
      flash.now[:alert] = "รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน"
      render :show
    end
  rescue => e
    Rails.logger.error "Password update error: #{e.message}"
    flash.now[:alert] = "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง"
    render :show
  end

  private

  def find_user_by_token
    @user = User.find_by_password_reset_token(params[:id])
    unless @user
      flash[:alert] = "ลิงค์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุแล้ว"
      redirect_to new_password_reset_path
    end
  end

  def check_token_expiration
    if @user&.password_reset_token_expired?
      flash[:alert] = "ลิงค์รีเซ็ตรหัสผ่านหมดอายุแล้ว กรุณาขอลิงค์ใหม่"
      redirect_to new_password_reset_path
    end
  end

  def password_reset_params
    params.permit(:email)
  end
end
