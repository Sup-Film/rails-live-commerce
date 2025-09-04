class FacebookLiveWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_request_signature, only: [:receive]

  #   skip_before_action :verify_authenticity_token - ปิด CSRF token เพื่อให้ Facebook เรียกได้
  # verify method - ใช้สำหรับ Facebook webhook verification challenge
  # receive method - รับ Live events จาก Facebook และส่งต่อไปยัง Service
  # verify_signature - ตรวจสอบลายเซ็นจาก Facebook เพื่อความปลอดภัย

  # GET endpoint สำหรับ Facebook verification
  def verify
    challenge = params["hub.challenge"]
    verify_token = params["hub.verify_token"]

    if verify_token == ENV["FACEBOOK_VERIFY_TOKEN"]
      render plain: challenge, status: :ok
    else
      render plain: "Unauthorized", status: :unauthorized
    end
  end

  # POST endpoint สำหรับรับข้อมูล Live events จาก Facebook และ Instagram
  def receive
    # ดึง entry_id จาก webhook - อาจเป็น page_id (Facebook) หรือ instagram_business_account_id (Instagram)
    entry_id = webhook_params.dig("entry", 0, "id")
    object_type = webhook_params["object"]
    
    unless entry_id
      Rails.logger.warn "entry_id is missing in the webhook parameters."
      return render json: { status: "ok" }, status: :ok
    end

    # หา Page ตาม object type
    page = if object_type == "instagram"
      # สำหรับ Instagram: หา page ที่มี instagram_business_account_id ตรงกับ entry_id
      Page.find_by(instagram_business_account_id: entry_id) || 
      Page.joins(:user).where(users: { instagram_user_id: entry_id }).first
    else
      # สำหรับ Facebook: ใช้ page_id เหมือนเดิม
      Page.find_by(page_id: entry_id)
    end
    
    unless page
      Rails.logger.warn "Page not found for entry_id: #{entry_id}, object: #{object_type}"
      return render json: { status: "ok" }, status: :ok
    end

    unless page.access_token.present?
      Rails.logger.warn "No page access token found for entry_id: #{entry_id}, object: #{object_type}"
      return render json: { status: "ok" }, status: :ok
    end

    # ส่งไปยัง service ที่เหมาะสม
    if object_type == "instagram"
      Rails.logger.info "Processing Instagram Live webhook for entry_id: #{entry_id}"
      InstagramLiveWebhookService.new(webhook_params, page.access_token, page.user).process
    else
      Rails.logger.info "Processing Facebook webhook for entry_id: #{entry_id}"
      FacebookLiveWebhookService.new(webhook_params, page.access_token, page.user).process
    end
    render json: { status: "ok" }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Error processing Facebook Live webhook: #{e.message}"
    render json: { error: "Internal Server Error" }, status: :internal_server_error
  end

  private

  def webhook_params
    params.permit! # รับทุก key
  end

  def verify_request_signature
    signature = request.headers["X-Hub-Signature-256"]

    unless signature
      Rails.logger.warn "Couldn't find 'X-Hub-Signature-256' in headers."
      return head :unauthorized
    end

    algo, signature_hash = signature.split("=", 2)
    unless algo == "sha256" && signature_hash.present?
      Rails.logger.warn "Invalid signature format."
      return head :unauthorized
    end

    body = request.body.read

    expected_hash = OpenSSL::HMAC.hexdigest("sha256", ENV["FACEBOOK_APP_SECRET"].to_s, body)

    unless ActiveSupport::SecurityUtils.secure_compare(signature_hash, expected_hash)
      Rails.logger.error "Couldn't validate the request signature."
      return head :unauthorized
    end

    request.body.rewind
  end
end
