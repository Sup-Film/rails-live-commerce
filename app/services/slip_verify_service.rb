class SlipVerifyService
  SLIP_VERIFY_NAME = 'verify_slip'.freeze
  APP_ID = '207219'.freeze
  BASE_URL = 'https://vrich-slip.vrich619.com:64321'.freeze
  
  def self.get_token
    url = URI("#{BASE_URL}/api/reset-token")

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)
    request["app_id"] = APP_ID

    response = https.request(request)
    
    unless response.code == '200'
      Rails.logger.error "Failed to get token: #{response.code} - #{response.body}"
      raise "ไม่สามารถรับ token ได้: #{response.code}"
    end
    
    response_data = JSON.parse(response.body)
    token = response_data['id_token']
    
    third_party = ThirdParty.find_or_create_by(name: SLIP_VERIFY_NAME) do |tp|
      tp.slug = SLIP_VERIFY_NAME
      tp.enabled = true
    end
    
    expiration_time = 24.hours.from_now
    third_party.update!(token: token, token_expire: expiration_time)
    
    Rails.logger.info "Token updated successfully for #{SLIP_VERIFY_NAME}"
    token
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing error: #{e.message}"
    raise "ไม่สามารถแปลงข้อมูล response ได้"
  rescue => e
    Rails.logger.error "Token retrieval error: #{e.message}"
    raise "เกิดข้อผิดพลาดในการรับ token: #{e.message}"
  end

  def self.verify_slip(sending_book, transaction_code)
    # Log ข้อมูลที่ใช้ตรวจสอบสลิป
    Rails.logger.info "Verifying slip - Sending bank: #{sending_book}, Transaction code: #{transaction_code}"

    # ตรวจสอบและค้นหา ThirdParty service สำหรับ slip verification
    verify_slip_service = ThirdParty.find_by(name: SLIP_VERIFY_NAME)

    # ถ้าไม่พบ ThirdParty record ให้คืน error
    unless verify_slip_service
      Rails.logger.error "ThirdParty record for #{SLIP_VERIFY_NAME} not found"
      return { "statusCode" => "9999", "message" => "ระบบตรวจสอบสลิปไม่พร้อมใช้งาน" }
    end

    # ดึง token สำหรับเรียก API
    token = verify_slip_service.token

    # ตรวจสอบว่า token หมดอายุหรือใกล้หมดอายุ ถ้าใช่ให้ขอ token ใหม่
    if verify_slip_service.token_expires_soon?
      Rails.logger.info "Token expired or expiring soon, getting new token"
      token = get_token
    end

    # เตรียม URL และสร้าง HTTP POST request สำหรับตรวจสอบสลิป
    url = URI("#{BASE_URL}/api/skybox")

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{token}"
    request.body = JSON.dump({
      "sendingBank" => sending_book,
      "transactionCode" => transaction_code,
    })

    # ส่ง request ไปยัง API และรับ response
    response = https.request(request)

    # ตรวจสอบ response code ถ้าไม่ใช่ 200 ให้คืน error
    unless response.code == '200'
      Rails.logger.error "Slip verification failed: #{response.code} - #{response.body}"
      return { "statusCode" => "9998", "message" => "ไม่สามารถตรวจสอบสลิปได้" }
    end

    # แปลง response เป็น JSON และ log ผลลัพธ์
    result = JSON.parse(response.body)
    Rails.logger.info "Slip verification result: #{result['statusCode']}"
    result

  rescue JSON::ParserError => e
    # จัดการกรณี response ไม่ใช่ JSON
    Rails.logger.error "JSON parsing error in slip verification: #{e.message}"
    { "statusCode" => "9997", "message" => "ไม่สามารถแปลงข้อมูลการตรวจสอบสลิปได้" }
  rescue => e
    # จัดการ error อื่น ๆ
    Rails.logger.error "Slip verification error: #{e.message}"
    { "statusCode" => "9996", "message" => "เกิดข้อผิดพลาดในการตรวจสอบสลิป: #{e.message}" }
  end
end
