class PagesController < ApplicationController
  skip_before_action :require_login, only: [:subscription_required], raise: false

  def subscription_required
    # This action can be used to render a page that informs the user they need a subscription
    # You can customize the view to provide more information or options for subscribing
  end

  private

  def require_login
    unless user_signed_in?
      redirect_to new_user_session_path, alert: "กรุณาเข้าสู่ระบบก่อนใช้บริการ"
    end
  end
end
