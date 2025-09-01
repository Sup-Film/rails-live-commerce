require "rails_helper"

RSpec.describe "Api::V1::Orders", type: :request do
  describe "POST /api/v1/orders/:token/submit_payment" do
    let(:seller) do
      User.create!(
        name: "Seller",
        email: "seller@example.com",
        password: "password",
        bank_account_number: "1466144693",
        bank_code: "014", # SCB
      )
    end

    let(:product) do
      Product.create!(
        productName: "Test Product",
        productDetail: "Detail",
        productPrice: 100.00,
        productCode: 123456,
        user: seller,
      )
    end

    let(:order) do
      Order.create!(
        order_number: "123456",
        product: product,
        user: seller,
        status: :awaiting_payment,
        quantity: 1,
        unit_price: product.productPrice,
        total_amount: product.productPrice,
        facebook_comment_id: "fb_c1",
        facebook_user_id: "fb_u1",
      )
    end

    def upload_fake_slip
      file = Tempfile.new(["slip", ".png"]); file.write("PNG"); file.rewind
      Rack::Test::UploadedFile.new(file.path, "image/png")
    end

    before do
      # Stub authentication to avoid dealing with real session in request specs
      allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(seller)
      allow_any_instance_of(Api::V1::BaseController).to receive(:authenticate_user!).and_return(true)

      # Seed seller credit so debit passes
      CreditLedger.create!(
        user: seller,
        entry_type: :top_up,
        amount_cents: 10_000,
        balance_after_cents: 10_000,
        idempotency_key: "seed_top_up",
      )
    end

    it "verifies slip, marks order paid, and saves payment" do
      allow(SlipVerifyService).to receive(:verify_slip).and_return(
        {
          "statusCode" => "0000",
          "data" => {
            "transRef" => "TRX_OK_1",
            "amount" => order.total_amount.to_s,
            "receiver" => {
              "account" => { "value" => seller.bank_account_number },
              "bank" => { "code" => seller.bank_code },
            },
          },
        }
      )

      expect do
        post "/api/v1/orders/#{order.checkout_token}/submit_payment",
             params: { payment: { sending_bank: "SCB", transaction_code: "ABC123", slip: upload_fake_slip } }
      end.to change { Payment.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(order.reload.paid?).to be true
      expect(order.payments.last.status).to eq("verified")
      expect(order.payments.last.external_ref).to eq("TRX_OK_1")
    end

    it "rejects when receiver account does not match seller" do
      allow(SlipVerifyService).to receive(:verify_slip).and_return(
        {
          "statusCode" => "0000",
          "data" => {
            "transRef" => "TRX_BAD_ACC",
            "amount" => order.total_amount.to_s,
            "receiver" => {
              "account" => { "value" => "9999999999" },
            },
          },
        }
      )

      post "/api/v1/orders/#{order.checkout_token}/submit_payment",
           params: { payment: { sending_bank: "SCB", transaction_code: "ABC123", slip: upload_fake_slip } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(order.reload.awaiting_payment?).to be true
      expect(order.payments.count).to eq(0)
    end

    it "returns 400 when slip is missing" do
      post "/api/v1/orders/#{order.checkout_token}/submit_payment",
           params: { payment: { sending_bank: "SCB", transaction_code: "ABC123" } }

      expect(response).to have_http_status(:bad_request)
      expect(order.reload.awaiting_payment?).to be true
    end

    it "rejects when amount does not match order total" do
      allow(SlipVerifyService).to receive(:verify_slip).and_return(
        {
          "statusCode" => "0000",
          "data" => {
            "transRef" => "TRX_BAD_AMT",
            "amount" => (order.total_amount.to_f + 1).to_s, # ทำให้ยอดผิด
            "receiver" => {
              "account" => { "value" => seller.bank_account_number },
              "bank" => { "code" => seller.bank_code },
            },
          },
        }
      )

      expect {
        post "/api/v1/orders/#{order.checkout_token}/submit_payment",
             params: { payment: { sending_bank: "SCB", transaction_code: "ABC123", slip: upload_fake_slip } }
      }.not_to change { Payment.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(order.reload.awaiting_payment?).to be true
    end

    it "rejects when slip transRef has been used before" do
      # เตรียม payment เดิมที่มี external_ref ซ้ำ
      existing = order.payments.new(amount_cents: order.total_amount_cents, status: "verified", external_ref: "TRX_DUP")
      existing.slip.attach(upload_fake_slip)
      existing.save!

      allow(SlipVerifyService).to receive(:verify_slip).and_return(
        {
          "statusCode" => "0000",
          "data" => {
            "transRef" => "TRX_DUP",
            "amount" => order.total_amount.to_s,
            "receiver" => { "account" => { "value" => seller.bank_account_number } },
          },
        }
      )

      expect {
        post "/api/v1/orders/#{order.checkout_token}/submit_payment",
             params: { payment: { sending_bank: "SCB", transaction_code: "ABC123", slip: upload_fake_slip } }
      }.not_to change { Payment.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(order.reload.awaiting_payment?).to be true
    end

    it "rejects when seller has no bank account configured" do
      seller.update!(bank_account_number: nil)

      allow(SlipVerifyService).to receive(:verify_slip).and_return(
        {
          "statusCode" => "0000",
          "data" => {
            "transRef" => "TRX_NO_SELLER_ACC",
            "amount" => order.total_amount.to_s,
            "receiver" => { "account" => { "value" => "1466144693" } }, # ค่ามั่ว ๆ แต่ต้องโดน reject ก่อนถึงขั้นนี้
          },
        }
      )

      expect {
        post "/api/v1/orders/#{order.checkout_token}/submit_payment",
             params: { payment: { sending_bank: "SCB", transaction_code: "ABC123", slip: upload_fake_slip } }
      }.not_to change { Payment.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(order.reload.awaiting_payment?).to be true
    end

    it "rejects when seller credit is insufficient (debit fails) and rolls back payment" do
      # เคลียร์เครดิตเริ่มต้นที่ before สร้างไว้ แล้วเติมน้อย ๆ
      seller.credit_ledgers.destroy_all
      CreditLedger.create!(
        user: seller,
        entry_type: :top_up,
        amount_cents: 1_000,
        balance_after_cents: 1_000,
        idempotency_key: "seed_low_credit",
      )

      allow(SlipVerifyService).to receive(:verify_slip).and_return(
        {
          "statusCode" => "0000",
          "data" => {
            "transRef" => "TRX_LOW_CREDIT",
            "amount" => order.total_amount.to_s,
            "receiver" => { "account" => { "value" => seller.bank_account_number } },
          },
        }
      )

      expect {
        post "/api/v1/orders/#{order.checkout_token}/submit_payment",
             params: { payment: { sending_bank: "SCB", transaction_code: "ABC123", slip: upload_fake_slip } }
      }.not_to change { Payment.count } # ควร rollback ไม่เหลือ payment verified

      expect(response).to have_http_status(:unprocessable_entity)
      expect(order.reload.awaiting_payment?).to be true
    end

    it "rejects when order is not in awaiting_payment state" do
      order.update!(status: :pending) # หรือ :paid, :cancelled ตามที่อยากทดสอบ

      post "/api/v1/orders/#{order.checkout_token}/submit_payment",
           params: { payment: { sending_bank: "SCB", transaction_code: "ABC123", slip: upload_fake_slip } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(order.reload.status).to eq("pending")
    end
  end
end
