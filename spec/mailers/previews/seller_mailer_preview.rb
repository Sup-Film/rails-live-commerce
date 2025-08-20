# Preview all emails at http://localhost:3000/rails/mailers/seller_mailer_mailer
class SellerMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/seller_mailer_mailer/insufficient_credit_notification
  def insufficient_credit_notification
    SellerMailer.insufficient_credit_notification
  end

end
