class PasswordResetMailer < ApplicationMailer
  default from: ENV.fetch('MAIL_FROM', 'noreply@localhost')

  def reset_email(user)
    @user = user
    @reset_url = password_reset_url(@user.reset_password_token)
    
    mail(
      to: @user.email,
      subject: 'รีเซ็ตรหัสผ่านของคุณ'
    )
  end
end
