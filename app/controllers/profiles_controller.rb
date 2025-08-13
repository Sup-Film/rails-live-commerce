class ProfilesController < ApplicationController
  before_action :require_login

  def show
  end

  private
  def require_login
    unless current_user
      redirect_to login_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end
end
