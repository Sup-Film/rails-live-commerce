class Api::V1::BaseController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_user!
  # สำหรับ API ที่เป็น public
  # skip_before_action :authenticate_user!, only: [:public_action]

  private

  def authenticate_user!
    return if current_user
    render json: { message: "กรุณาเข้าสู่ระบบก่อนใช้งาน", error: "unauthorized" }, status: :unauthorized
  end
end
