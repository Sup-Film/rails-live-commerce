class DashboardsController < ApplicationController
  before_action :require_login

  # GET /dashboard
  def show
    @orders = current_user.orders.order(created_at: :desc).page(params[:page]).per(10)
  end

  private

  def require_login
    unless user_signed_in?
      redirect_to new_user_session_path, alert: "กรุณาเข้าสู่ระบบก่อน"
    end
  end
end