class Api::V1::CreditsController < ApplicationController
  def top_up
    # ตรวจสอบ Parameter
    unless slip_params[:sending_book].present? && slip_params[:transaction_code].present?
      return render json: {
                      message: "กรุณาระบุข้อมูลสลิปให้ครบถ้วน",
                      errors: {
                        sending_book: "จำเป็นต้องระบุ",
                        transaction_code: "จำเป็นต้องระบุ",
                      },
                    }, status: :bad_request
    end

    # # ตรวจสอบสลิปผ่าน SlipVerifyService
    data_verify = SlipVerifyService.verify_slip(
      slip_params[:sending_book],
      slip_params[:transaction_code]
    )

    unless data_verify["statusCode"] == "0000"
      return render json: {
                      message: data_verify["message"] || "ใบเสร็จไม่ถูกต้อง หรือ ไม่สามารถตรวจสอบได้",
                    }, status: :unprocessable_entity
    end

    verified_data = data_verify["data"]
    trans_ref = verified_data["transRef"]
    amount_cents = verified_data["amount"].to_f * 100 # แปลงเป็น Cents

    # Mockup data
    # verified_data = {
    #   "transRef" => "mock_trans_ref_#{SecureRandom.hex(6)}",
    #   "amount" => "500"
    # }
    # trans_ref = verified_data["transRef"]
    # amount_cents = (verified_data["amount"].to_f * 100).round # แปลงเป็น Cents

    # 4. เรียกใช้ CreditService เพื่อเติมเงิน
    CreditService.top_up(
      user: current_user,
      amount_cents: amount_cents,
      idempotency_key: trans_ref,
      notes: "Top-up via slip verification. Ref: #{trans_ref}",
    )

    # response
    render json: {
      success: true,
      message: "เติมเครดิตสำเร็จ! ยอดเงิน #{verified_data["amount"]} บาท ถูกเพิ่มเข้าสู่บัญชีของคุณแล้ว",
      new_balance: current_user.reload.credit_balance,
    }, status: :ok
    
  rescue CreditService::IdempotencyKeyInUseError
    render json: { success: false, message: "สลิปนี้เคยถูกใช้เพื่อเติมเงินไปแล้ว" }, status: :conflict
  rescue => e
    Rails.logger.error "Credit top-up error: #{e.message}"
    render json: { success: false, message: "เกิดข้อผิดพลาดในระบบ: #{e.message}" }, status: :internal_server_error
  end

  private

  def slip_params
    params.permit(:sending_book, :transaction_code)
  end
end
