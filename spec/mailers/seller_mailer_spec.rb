require "rails_helper"

RSpec.describe SellerMailer, type: :mailer do
  describe "insufficient_credit_notification" do
    let(:mail) { SellerMailer.insufficient_credit_notification }

    it "renders the headers" do
      expect(mail.subject).to eq("Insufficient credit notification")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

end
