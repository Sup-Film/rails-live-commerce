module SubscriptionManagement
  extend ActiveSupport::Concern

  included do
    # ทำให้เมธอดนี้สามารถเข้าถึงได้จาก view
    helper_method :active_subscription?
  end

  def active_subscription?
    # ตรวจสอบว่าผู้ใช้ล็อกอินอยู่และมีการสมัครสมาชิกที่สถานะ 'active'
    user_signed_in? && current_user.subscriptions.exists?(status: 'active')
  end

  # Before action
  def check_active_subscription
    unless active_subscription?
      redirect_to subscription_required_path, alert: 'คุณต้องสมัครบริการรายเดือนเพื่อเข้าใช้งานระบบ'
    end
  end
end
