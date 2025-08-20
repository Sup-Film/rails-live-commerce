class SellerMailer < ApplicationMailer
  # ตั่งค่าผู้ส่งอีเมลเริ่มต้น
  default from: "no-reply@example.com"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.seller_mailer.insufficient_credit_notification.subject
  #
  def insufficient_credit_notification(user:, order_details:, required_credit:)
    # รับค่าเป็น keyword args เพื่อให้ ActionMailer/ActiveJob สามารถ serialize ได้ดี
    @user = GlobalID::Locator.locate_signed(user) || user
    # If user is passed as GlobalID, locate it; otherwise use directly
    @order_details = order_details
    @required_credit = required_credit / 100 # แปลงเป็นหน่วยบาทสำหรับแสดงผล
    @current_balance = @user.credit_balance_cents / 100

    mail(to: @user.email, subject: "เครดิตของคุณไม่เพียงพอสำหรับการสร้างออเดอร์ใหม่")
  end
end
