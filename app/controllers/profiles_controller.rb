class ProfilesController < ApplicationController
  before_action :require_login

  def index
    @user = current_user
  end

  def show
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated successfully."
    else
      render :edit
    end
  end

  private

  def require_login
    unless current_user
      redirect_to login_path, alert: "กรุณาเข้าสู่ระบบก่อนดำเนินการ."
    end
  end

  def profile_params
    params.require(:user).permit(:name, :bank_account_number, :bank_account_name, :bank_code)
  end
end
