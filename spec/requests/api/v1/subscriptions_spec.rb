require "rails_helper"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  describe "POST /api/v1/subscription/verify_slip" do
    # สร้าง user จำลองสำหรับทุกเทสในไฟล์นี้
    let(:user) { User.create(name: "Test User", email: "test@example.com", password: "password") }

    # สร้างตัวแปรสำหรับ Path เพื่อง่ายต่อการเรียกใช้
    let(:verify_slip_path) { "/api/v1/subscription/verify_slip" }

    let(:login_path) { "/login" }

    describe "POST /verify_slip" do
      # Context 1: กรณีที่สลิปถูกต้องและยังไม่เคยถูกใช้งาน
      context "when the slip is valid and unused" do
        before do
          # จำลอง Stub การทำงานของ SlipVerifyService
          # ให้ return ค่ากลับมาเหมือนกับว่าตรวจสอบสำเร็จ
          allow(SlipVerifyService).to receive(:verify_slip).and_return({
            "statusCode" => "0000",
            "data" => {
              "transRef" => "UNIQUE_TRANS_REF_20250806",
              "amount" => "299.00",
              "receiver" => {
                "account" => {
                  "value" => "146-6-14469-3", # เลขบัญชีที่ถูกต้อง
                },
              },
            },
          }.with_indifferent_access) # .with_indifferent_access ทำให้เราเรียก key เป็น string หรือ symbol ก็ได้

          # ยิง request ไปที่ endpoint login เพื่อสร้าง session
          post login_path, params: { session: { email: user.email, password: "password" } }
          expect(response).to redirect_to(root_path) # ตรวจสอบว่า login สำเร็จและถูก redirect
        end

        it "creates a new subscription and returns a success message" do
          # เตรียม params ที่จะส่ง
          slip_params = {
            sending_book: "KTB",
            transaction_code: "1234567890",
          }

          # ยิง POST request ไปที่ API (ต้อง login เป็น user ก่อน)
          post verify_slip_path, params: slip_params

          # ตรวจสอบว่า response มี status code 200
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response["message"]).to eq("เปิดใช้งานสมาชิกสำเร็จ!")

          # ตรวจสอบข้อมูลใน Database
          user.reload
          expect(user.subscriptions.count).to eq(1)
          subscription = user.subscriptions.first
          expect(subscription.status).to eq("active")
          expect(subscription.payment_reference).to eq("UNIQUE_TRANS_REF_20250806")
          expect(subscription.expires_at).to be_within(1.minute).of(1.month.from_now)
        end
      end
    end
  end
end
