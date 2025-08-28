class SubscriptionsController < ApplicationController
  before_action :require_login
  before_action :find_subscription, only: [:show]

  def show
    @subscription
    redirect_to new_subscription_path if @subscription.nil?
  end

  def new
    @subscription = current_user.subscriptions.first_or_initialize
  end

  def create
  end

  private

  def require_login
    unless user_signed_in?
      redirect_to new_user_session_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end

  def find_subscription
    @subscription = current_user.subscriptions.first
  end

  # def check_existing_subscription_more_than_3_days
  #   if current_user.subscribed? && current_user.current_subscription.days_until_expiry > 3
  #     redirect_to subscription_path, alert: "คุณมีสถานะสมาชิกที่กำลังรออนุมัติหรือใช้งานอยู่แล้ว (เหลืออีก #{current_user.current_subscription.days_until_expiry} วัน)"
  #   end
  # end

  def subscription_params
    params.require(:subscription).permit(:payment_slip)
  end
end
