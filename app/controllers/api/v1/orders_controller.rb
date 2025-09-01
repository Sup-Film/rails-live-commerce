class Api::V1::OrdersController < Api::V1::BaseController
  before_action :find_order
  skip_before_action :authenticate_user!, only: :submit_payment

  # POST /api/v1/orders/:token/submit_payment
  def submit_payment
    Rails.logger.info "[OrdersController] submit_payment token=#{params[:token]}"

    # 1) ตรวจสอบสถานะออเดอร์
    unless @order.awaiting_payment?
      return render json: { success: false, message: "ออเดอร์นี้ไม่ได้อยู่ในสถานะรอชำระเงิน" }, status: :unprocessable_entity
    end

    # 2) ตรวจสอบพารามิเตอร์จากฟรอนต์เอนด์
    unless payment_params[:sending_bank].present? && payment_params[:transaction_code].present? && payment_params[:slip].present?
      return render json: { success: false, message: "ข้อมูลสลิปไม่ครบถ้วน" }, status: :bad_request
    end

    # 3) สร้าง Payment พร้อมแนบสลิป (จะบันทึกเมื่อ verify ผ่าน)
    payment = @order.payments.new(amount_cents: @order.total_amount_cents, status: "pending")
    payment.slip.attach(payment_params[:slip])

    begin
      # 4) ตรวจสลิปกับผู้ให้บริการ
      data_verify = SlipVerifyService.verify_slip(payment_params[:sending_bank], payment_params[:transaction_code])

      # 5) ตรวจความถูกต้อง: status, amount, duplicate, receiver account = บัญชีแม่ค้า
      trans_ref = validate_payment!(@order, data_verify)

      # 6) บันทึกผลสำเร็จ: ยืนยัน payment, เดบิตค่าส่ง, อัปเดต order
      process_successful_payment(payment, @order, trans_ref)

      render json: { success: true, message: "การชำระเงินได้รับการยืนยันเรียบร้อยแล้ว!" }, status: :ok
    rescue => e
      Rails.logger.error "[OrdersController] submit_payment error: #{e.message}"
      render json: { success: false, message: e.message }, status: :unprocessable_entity
    end
  end

  private

  def find_order
    @order = Order.find_by!(checkout_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: "ไม่พบออเดอร์" }, status: :not_found
  end

  def payment_params
    params.require(:payment).permit(:sending_bank, :transaction_code, :slip)
  end

  def validate_payment!(order, verified)
    raise "สลิปไม่ถูกต้อง หรือไม่สามารถตรวจสอบได้" unless verified["statusCode"] == "0000"

    data = verified["data"]
    trans_ref = data["transRef"]
    amount_verified_cents = (data["amount"].to_f * 100).to_i

    # 1) ตรวจยอด
    raise "ยอดชำระไม่ถูกต้อง" unless amount_verified_cents == order.total_amount_cents

    # 2) กันสลิปซ้ำ
    raise "สลิปนี้เคยถูกใช้ในการชำระเงินอื่นแล้ว" if Payment.exists?(external_ref: trans_ref)

    # 3) ตรวจบัญชีผู้รับ = บัญชีแม่ค้า
    receiver_bank_no = extract_receiver_bank_number(data)
    expected_receiver = order.user.bank_account_number.to_s.gsub("-", "")
    raise "ผู้ขายยังไม่ได้ตั้งค่าบัญชีรับเงิน" if expected_receiver.blank?
    raise "บัญชีผู้รับเงินไม่ถูกต้อง" unless receiver_bank_no.present? && receiver_bank_no == expected_receiver

    # 4) (ทางเลือก) ตรวจธนาคาร ถ้ามีข้อมูล
    receiver_bank_code = extract_receiver_bank_code(data)
    expected_bank_code = order.user.bank_code.to_s
    raise "ผู้ขายยังไม่ได้ตั้งรหัสธนาคาร" if expected_bank_code.blank?
    raise "สลิปไม่มีข้อมูลรหัสธนาคารผู้รับ" if receiver_bank_code.blank?

    raise "ธนาคารผู้รับไม่ตรงกับที่กำหนด" if receiver_bank_code != expected_bank_code

    trans_ref
  end

  def process_successful_payment(payment, order, trans_ref)
    ActiveRecord::Base.transaction do
      payment.update!(status: "verified", external_ref: trans_ref, verified_at: Time.current)

      seller = order.user
      shipping_cost_cents = 5000 # TODO: Replace with ShippingService or config

      CreditService.debit(
        user: seller,
        amount_cents: shipping_cost_cents,
        idempotency_key: "shipping_debit_order_#{order.id}",
        reference: order,
        notes: "Shipping cost for Order ##{order.order_number}",
      )

      order.update!(status: :paid, paid_at: Time.current)
    end
  end

  # Helpers to extract receiver info from verified payload (provider dependent)
  def extract_receiver_bank_number(verified_data)
    verified_data.dig("receiver", "proxy", "value")&.gsub("-", "") ||
      verified_data.dig("receiver", "account", "value")&.gsub("-", "")
  end

  def extract_receiver_bank_code(verified_data)
    verified_data.dig("receiver", "bank", "code")
  end
end
