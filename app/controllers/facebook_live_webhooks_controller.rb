class FacebookLiveWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verifyRequestSignature, only: [:receive]

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
    # ดึง UID ของ user เพื่อใช้ในการดึง access token
    uid = webhook_params["entry"].first["uid"] if webhook_params["entry"].present? && webhook_params["entry"].first["uid"].present?
    unless uid
      Rails.logger.warn "UID is missing in the webhook parameters."
      return render json: { error: "UID is missing" }, status: :bad_request
    end

    user = User.find_by(uid: uid) if uid.present?
    unless user
      Rails.logger.warn "User not found for UID: #{uid}"
      return render json: { error: "User not found" }, status: :not_found
    end

    unless user.oauth_token
      Rails.logger.warn "No access token found for user with UID: #{uid}"
      return render json: { error: "Access token is missing" }, status: :unauthorized
    end

    FacebookLiveWebhookService.new(webhook_params, user.oauth_token, user).process
    render json: { status: "ok" }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Error processing Facebook Live webhook: #{e.message}"
    render json: { error: "Internal Server Error" }, status: :internal_server_error
  end

  private

  def webhook_params
    params.permit! # รับทุก key
  end

  def verifyRequestSignature
    signature = request.headers["X-Hub-Signature-256"]

    unless signature
      Rails.logger.warn "Couldn't find 'X-Hub-Signature-256' in headers."
      return head :unauthorized
    end

    elements = signature.split("=")
    signature_hash = elements[1]

    body = request.body.read

    expected_hash = OpenSSL::HMAC.hexdigest("sha256", ENV["FACEBOOK_APP_SECRET"], body)

    unless signature_hash == expected_hash
      Rails.logger.error "Couldn't validate the request signature."
      return head :unauthorized
    end

    request.body.rewind
  end
end
