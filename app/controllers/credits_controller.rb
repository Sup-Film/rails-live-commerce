class CreditsController < ApplicationController
  before_action :require_login
  before_action :check_active_subscription

  def new
    @current_balance = current_user.credit_balance
  end

  private

  def require_login
    unless user_signed_in?
      redirect_to new_user_session_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end

  def check_active_subscription
    # ตรวจสอบว่ามี subscription ที่ active หรือไม่
    unless check_active_subscription?
      redirect_to subscription_required_path, alert: "คุณต้องสมัครบริการรายเดือนเพื่อใช้งานระบบเครดิต"
    end
  end
end
