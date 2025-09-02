class VerifyOrderPaymentJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    payment = Payment.find_by(id: payment_id)
    return unless payment&.pending?

    order = payment.payable
    return unless order.is_a?(Order)

    # 1. สแกน QR Code จากสลิป
    # Active Storage ทำให้เราสามารถเข้าถึงไฟล์ได้ง่ายๆ
    slip_blob = payment.slip.blob
    qr_data_string = QrScanner.scan_image(slip_blob.download) # สมมติว่ามี Service/Library นี้

    # if amount_verified == order.total_amount && ... (เงื่อนไขอื่นๆ)
    process_successful_payment(payment, order, "TRANS_REF_12345")
    # else
    # --- ถ้าสลิปไม่ถูกต้อง ---
    # payment.update(status: 'rejected', metadata: { reason: "ยอดเงินไม่ตรง" })
    # end
  rescue => e
    # payment.update(status: 'failed', metadata: { error: e.message })
    Rails.logger.error "VerifyOrderPaymentJob failed for Payment ##{payment.id}: #{e.message}"
  end

  private

  def validate_slip_data(qr_data_string)
    # ตรวจสอบ Parameter
    # unless slip_params[:sending_book].present? && slip_params[:transaction_code].present?
    #   return render json: {
    #                   message: "กรุณาระบุข้อมูลสลิปให้ครบถ้วน",
    #                   errors: {
    #                     sending_book: "จำเป็นต้องระบุ",
    #                     transaction_code: "จำเป็นต้องระบุ",
    #                   },
    #                 }, status: :bad_request
    # end

    # # ตรวจสอบสลิปผ่าน SlipVerifyService
    # data_verify = SlipVerifyService.verify_slip(
    #   slip_params[:sending_book],
    #   slip_params[:transaction_code]
    # )

    # unless data_verify["statusCode"] == "0000"
    #   return render json: {
    #                   message: data_verify["message"] || "ใบเสร็จไม่ถูกต้อง หรือ ไม่สามารถตรวจสอบได้",
    #                 }, status: :unprocessable_entity
    # end

    # verified_data = data_verify["data"]
    # trans_ref = verified_data["transRef"]
    # amount_cents = verified_data["amount"].to_f * 100 # แปลงเป็น Cents
  end

  def process_successful_payment(payment, order, trans_ref)
    payment.update!(
      status: "verified",
      external_ref: trans_ref,
      verified_at: Time.current,
    )

    # หักเครดิตผู้ขาย (เรียกใช้ Logic เดิมที่เราทำไว้)
    seller = order.user
    # TODO: ต้องแทนที่ด้วย SkyboxService เพื่อเช็คราคาขนส่ง
    shipping_cost_cents = 5000

    CreditService.debit(
      user: seller,
      amount_cents: shipping_cost_cents,
      idempotency_key: "shipping_debit_order_#{order.id}",
      reference: order,
      notes: "Shipping cost for Order ##{order.order_number}",
    )

    # อัปเดตสถานะออเดอร์
    order.update!(status: :paid, paid_at: Time.current)

    # TODO: ส่ง Notification แจ้งผู้ซื้อและผู้ขายว่าชำระเงินสำเร็จแล้ว
  end

  def slip_params
    params.permit(:sending_book, :transaction_code)
  end
end
