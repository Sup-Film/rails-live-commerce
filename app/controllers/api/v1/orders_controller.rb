class Api::V1::OrdersController < ActionController::API
  before_action :find_order

  # POST /api/v1/orders/:token/submit_payment
  def submit_payment
    binding.pry
    # 1. ตรวจสอบสถานะและ Parameters ที่ส่งมาจาก JS
    unless @order.awaiting_payment?
      return render json: { success: false, message: "ออเดอร์นี้ไม่ได้อยู่ในสถานะรอชำระเงิน" }, status: :unprocessable_entity
    end

    unless payment_params[:sending_bank].present? && payment_params[:transaction_code].present? && payment_params[:slip].present?
      return render json: { success: false, message: "ข้อมูลสลิปไม่ครบถ้วน" }, status: :bad_request
    end

    # สร้าง Payment record (ยังไม่ save)
    # เรายังคงสร้าง Payment record เพื่อติดตามประวัติการพยายามชำระเงิน
    payment = @order.payments.new(
      amount_cents: @order.total_amount_cents,
      status: "pending",
    )

    payment.slip.attach(payment_params[:slip])

    begin
      verified_data = {
        "transRef" => "mock_trans_ref_order_#{SecureRandom.hex(6)}",
        "amount" => @order.total_amount.to_s
      }
      # 2. เรียก SlipVerifyService โดยใช้ข้อมูลจาก Frontend โดยตรง
      # verified_data = SlipVerifyService.verify_slip(
      #   payment_params[:sending_bank],
      #   payment_params[:transaction_code]
      # )

      # 3. ตรวจสอบเงื่อนไขทั้งหมด
      # validate_payment!(@order, verified_data)

      trans_ref = verified_data["transRef"]

      # 4. ถ้าทุกอย่างถูกต้อง -> ทำการบันทึกและหักเครดิต
      process_successful_payment(payment, @order, trans_ref)

      render json: { success: true, message: "การชำระเงินได้รับการยืนยันเรียบร้อยแล้ว!" }, status: :ok
    rescue => e
      # 5. ถ้าเกิด Error ใดๆ ขึ้น
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

  def validate_payment!(order, verified_data)
    raise "สลิปไม่ถูกต้อง หรือไม่สามารถตรวจสอบได้" unless verified_data["statusCode"] == "0000"

    data = verified_data["data"]
    trans_ref = data["transRef"]
    amount_verified_cents = data["amount"].to_f * 100

    raise "ยอดชำระไม่ถูกต้อง" unless amount_verified_cents.to_i == order.total_amount_cents

    # raise "บัญชีผู้รับเงินไม่ถูกต้อง" # (ใส่ Logic ตรวจสอบบัญชีผู้รับที่นี่)

    raise "สลิปนี้เคยถูกใช้ในการชำระเงินอื่นแล้ว" if Payment.exists?(external_ref: trans_ref)
  end

  def process_successful_payment(payment, order, trans_ref)
    ActiveRecord::Base.transaction do
      # บันทึก Payment
      payment.status = "verified"
      payment.external_ref = trans_ref
      payment.verified_at = Time.current
      payment.save!

      seller = order.user
      shipping_cost_cents = 5000 # TODO: Replace with ShippingService

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
end
