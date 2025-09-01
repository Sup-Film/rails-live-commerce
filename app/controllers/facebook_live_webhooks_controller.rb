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

  # POST endpoint สำหรับรับข้อมูล Live events จาก Facebook
  def receive
    # ดึง page_id ของเพจจาก webhook แล้วแมปไปยัง Page Access Token
    page_id = webhook_params.dig("entry", 0, "id")
    unless page_id
      Rails.logger.warn "page_id is missing in the webhook parameters."
      return render json: { status: "ok" }, status: :ok
    end

    page = Page.find_by(page_id: page_id)
    unless page
      Rails.logger.warn "Page not found for page_id: #{page_id}"
      return render json: { status: "ok" }, status: :ok
    end

    unless page.access_token.present?
      Rails.logger.warn "No page access token found for page_id: #{page_id}"
      return render json: { status: "ok" }, status: :ok
    end

    FacebookLiveWebhookService.new(webhook_params, page.access_token, page.user).process
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
