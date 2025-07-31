class SubscriptionsController < ApplicationController
  before_action :require_login
  before_action :find_subscription, only: [:show]
  before_action :check_existing_subscription, only: [:new, :create]

  def show
    @subscription
    redirect_to new_subscription_path if @subscription.nil?
  end

  def new
    @subscription = Subscription.new
  end

  def create
    @subscription = current_user.subscriptions.build(subscription_params)

    # if @subscription.save
    #   redirect_to subscription_path, notice: "คำขอสมัครสมชิกของคุณถูกส่งเรียบร้อยแล้ว กรุณารอการอนุมัติ"
    # else
    #   render :new, status: :unprocessable_entity
    # end
  end

  private

  def require_login
    unless user_signed_in?
      redirect_to new_user_session_path, alert: "กรุณาเข้าสู่ระบบก่อนใช้บริการ"
    end
  end

  def find_subscription
    @subscription = current_user.subscriptions.first
  end

  def check_existing_subscription
    if current_user.subscriptions.where(status: ["active", "pending_approval"]).exists?
      redirect_to subscription_path, alert: "คุณมีสถานะสมาชิกที่กำลังรออนุมัติหรือใช้งานอยู่แล้ว"
    end
  end

  def subscription_params
    params.require(:subscription).permit(:payment_slip)
  end
end
