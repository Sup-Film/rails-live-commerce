class Api::V1::SubscriptionsController < Api::V1::BaseController
  before_action :authenticate_user!

  # POST /api/v1/subscriptions/verify_slip

  # ค่าคงที่สำหรับการตรวจสอบ
  REQUIRED_AMOUNT = 299.00
  OUR_BANK_NUMBER = "1466144693".freeze
  # ถ้ามีวันเหลือมากกว่าค่านี้ ระบบจะถือว่าไม่ต้องต่ออายุ (ป้องกันการต่ออายุก่อนเวลา)
  RENEWAL_BLOCK_THRESHOLD_DAYS = 30

  def verify_slip
    # logger.info "Verifying slip with params: #{JSON.pretty_generate(slip_params)}"

    # ตรวจสอบ parameters
    unless slip_params[:sending_book].present? && slip_params[:transaction_code].present?
      return render json: {
                      message: "กรุณาระบุข้อมูลสลิปให้ครบถ้วน",
                      errors: {
                        sending_book: "จำเป็นต้องระบุ",
                        transaction_code: "จำเป็นต้องระบุ",
                      },
                    }, status: :bad_request
    end

    # ตรวจสอบว่าผู้ใช้มี subscription อยู่แล้วและยังไม่หมดอายุ
    subscription = current_user.current_subscription
    if subscription_conflict?(subscription)
      return render json: {
                      message: "คุณมีสมาชิกที่ใช้งานอยู่แล้ว",
                      subscription: {
                        status: subscription.status,
                        expires_at: subscription.expires_at,
                      },
                    }, status: :conflict
    end

    # ตรวจสอบสลิปผ่าน SlipVerifyService
    data_verify = SlipVerifyService.verify_slip(
      slip_params[:sending_book],
      slip_params[:transaction_code]
    )

    # Mockup
    # data_verify = {
    #   "statusCode" => "0000",
    #   "message" => "ตรวจสอบสำเร็จ",
    #   "data" => {
    #     "transRef" => "TRX123452",
    #     "receiver" => {
    #       "proxy" => {
    #         "value" => "1466144693",
    #       },
    #       "account" => {
    #         "value" => "1466144693",
    #       },
    #     },
    #     "amount" => 299.00,
    #   },
    # }

    trans_ref = validated_payment(data_verify)
    return if performed? # ถ้า validated_payment? มีการ render แล้วให้หยุดการทำงาน

    # สร้างหรืออัปเดต subscription
    create_or_update_subscription(trans_ref)
  rescue => e
    Rails.logger.error "Subscription verification error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: {
      message: "เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่อีกครั้ง",
    }, status: :internal_server_error
  end

  private

  def slip_params
    params.permit(:sending_book, :transaction_code)
  end

  def extract_receiver_bank_number(verified_data)
    verified_data.dig("receiver", "proxy", "value")&.gsub("-", "") ||
    verified_data.dig("receiver", "account", "value")&.gsub("-", "")
  end

  def subscription_conflict?(subscription)
    # ปัจจุบัน policy: ห้ามสมัคร/ต่ออายุ หากมีสถานะ active และเหลือวันมากกว่าค่ากำหนด
    subscription&.active? && subscription.days_until_expiry > RENEWAL_BLOCK_THRESHOLD_DAYS
  end

  def validated_payment(data_verify)
    unless data_verify["statusCode"] == "0000"
      return render json: {
                      message: data_verify["message"] || "ใบเสร็จไม่ถูกต้อง หรือ ไม่สามารถตรวจสอบได้",
                    }, status: :unprocessable_entity
    end

    verified_data = data_verify["data"]
    trans_ref = verified_data["transRef"]

    # ตรวจสอบว่าสลิปนี้ถูกใช้ไปแล้วหรือไม่
    if Subscription.exists?(payment_reference: trans_ref)
      return render json: {
                      message: "สลิปนี้ถูกใช้งานเพื่อสมัครสมาชิกไปแล้ว",
                    }, status: :conflict
    end

    # ตรวจสอบบัญชีผู้รับเงิน
    receiver_bank_no = extract_receiver_bank_number(verified_data)
    unless receiver_bank_no == OUR_BANK_NUMBER
      return render json: {
                      message: "บัญชีผู้รับเงินไม่ถูกต้อง",
                    }, status: :unprocessable_entity
    end

    # ตรวจสอบยอดเงิน
    unless verified_data["amount"].to_f == REQUIRED_AMOUNT
      return render json: {
                      message: "ยอดเงินไม่ถูกต้อง (ต้องเป็น #{REQUIRED_AMOUNT} บาท)",
                    }, status: :unprocessable_entity
    end

    trans_ref
  end

  def create_or_update_subscription(trans_ref)
    ActiveRecord::Base.transaction do
      subscription = current_user.subscriptions.first_or_initialize
      # ถ้า subscription มีสถานะ active และยังไม่หมดอายุ ให้ต่ออายุจาก expires_at เดิม
      if subscription.persisted? && subscription.active? && subscription.expires_at.present? && subscription.expires_at > Time.current
        new_expires_at = subscription.expires_at + 1.month
        subscription.assign_attributes(
          status: :active,
          expires_at: new_expires_at,
          subscribed_at: Time.current,
          payment_reference: trans_ref,
        )
      else
        # กรณีสมัครใหม่หรือหมดอายุแล้ว ให้เริ่มจาก now
        subscription.assign_attributes(
          status: :active,
          expires_at: 1.month.from_now,
          subscribed_at: Time.current,
          payment_reference: trans_ref,
        )
      end

      if subscription.save
        ProcessHeldOrdersJob.perform_later(current_user.id)

        render json: {
          message: "เปิดใช้งานสมาชิกสำเร็จ!",
          subscription: {
            status: subscription.status,
            expires_at: subscription.expires_at,
            subscribed_at: subscription.subscribed_at,
          },
        }, status: :ok
      else
        render json: {
          message: "ไม่สามารถบันทึกข้อมูลได้",
          errors: subscription.errors.full_messages,
        }, status: :unprocessable_entity
      end
    end
  end
end
