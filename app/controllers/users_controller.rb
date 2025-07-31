class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    Rails.logger.info "Creating user with params: #{user_params.inspect}"
    @user = User.new(user_params)
    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: 'สมัครสมาชิกสำเร็จ!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
