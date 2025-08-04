class Api::V1::SubscriptionsController < ActionController::API
  def verify_slip
    sending_book = params["sending_book"]
    transaction_code = params["transaction_code"]
    binding.pry
    data_Verify = SlipVerifyService.verify_slip(sending_book, transaction_code)

    unless data_Verify["statusCode"] == "0000"
      return render json: { message: "ใบเสร็จไม่ถูกต้อง หรือ ไม่สามารถตรวจสอบได้" }, status: :unprocessable_entity
    end

    verified_data = data_Verify["data"]
    trans_ref = verified_data["transRef"]

    if Subscription.exists?(payment_reference: trans_ref)
      return render json: { message: "สลิปนี้ถูกใช้งานเพื่อสมัครสมาชิกไปแล้ว" }, status: :conflict
    end

    receiver_bank_no = verified_data.dig("receiver", "proxy", "value")&.gsub("-", "") ||
                      verified_data.dig("receiver", "account", "value")&.gsub("-", "")

    our_bank_no_ref = "1466144693"

    unless receiver_bank_no == our_bank_no_ref
      return render json: { message: "บัญชีผู้รับเงินไม่ถูกต้อง" }, status: :unprocessable_entity
    end

    # (Optional) 4. ตรวจสอบยอดเงินให้ตรงกับค่าสมาชิก
    unless verified_data["amount"].to_f == 299.00
      return render json: { message: "ยอดเงินไม่ถูกต้อง (ต้องเป็น 299.00 บาท)" }, status: :unprocessable_entity
    end

    begin
      subscription = current_user.subscriptions.first_or_initialize
      subscription.update!(
        status: :active,
        expires_at: 1.month.from_now,
        subscribed_at: Time.current,
        payment_reference: trans_ref,
      )

      render json: { message: "เปิดใช้งานสมาชิกสำเร็จ!" }, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      # หากการบันทึกผิดพลาด (เช่น validation ไม่ผ่าน)
      render json: { message: "ไม่สามารถบันทึกข้อมูลได้: #{e.message}" }, status: :unprocessable_entity
    end
  end
end
