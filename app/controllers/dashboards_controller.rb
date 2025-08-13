class DashboardsController < ApplicationController
  # include SubscriptionManagement
  before_action :require_login
  before_action :check_active_subscription

  # GET /dashboard
  def show
    @orders = current_user.orders.order(created_at: :desc).page(params[:page]).per(10)
  end

  private

  def require_login
    unless user_signed_in?
      redirect_to new_user_session_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end

  # Method สำหรับตรวจสอบสถานะสมาชิก
  def check_active_subscription
    unless check_active_subscription?
      redirect_to subscription_required_path, alert: "กรุณาสมัครสมาชิกรายเดือนก่อนเข้าใช้งานระบบ."
    end
  end
end