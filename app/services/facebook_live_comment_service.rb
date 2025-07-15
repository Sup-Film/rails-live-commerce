class FacebookLiveCommentService
  def initialize(live_id, access_token = nil, user = nil)
    @live_id = live_id
    @access_token = access_token
    @user = user # ใช้สำหรับหา Merchant ในการสร้าง Order
  end

  def fetch_comments
    # url = "https://streaming-graph.facebook.com/#{live_id}/live_comments?access_token=#{@access_token}&comment_rate=one_per_two_seconds&fields=from{name,id},message',created_time"
    # response = HTTParty.get(url)
    # if response.success?
    # comments = response.parsed_response["data"] || [] # ถ้ามีข้อมูลใน 'data' ให้ใช้ ถ้าไม่มีก็ใช้เป็น Array ว่าง
    # Rails.logger.info "Fetched #{comments.size} comments for Facebook Live ID: #{@live_id}"

    # Mock response data for testing
    comments = [
      { "id" => "1234567890", "message" => "CF 123", "created_time" => "2023-10-01T12:00:00+0000", "from" => { "id" => "user123", "name" => "ผู้ใช้ตัวอย่าง" } },
      { "id" => "12345678900", "message" => "CF 456", "created_time" => "2023-10-01T12:00:00+0000", "from" => { "id" => "user123", "name" => "ผู้ใช้ตัวอย่าง" } },
      { "id" => "123456789010", "message" => "CF 2828", "created_time" => "2023-10-01T12:00:00+0000", "from" => { "id" => "user123", "name" => "ผู้ใช้ตัวอย่าง1" } },
      { "id" => "123456789011", "message" => "CF 456", "created_time" => "2023-10-01T12:00:00+0000", "from" => { "id" => "user123", "name" => "ผู้ใช้ตัวอย่าง2" } },
      { "id" => "0987654321", "message" => "สวัสดีครับ", "created_time" => "2023-10-01T12:05:00+0000", "from" => { "id" => "user456", "name" => "ผู้ใช้ตัวอย่าง" } },
    ]

    # นำข้อมูลใน comment มาวนลูป และทำการสร้าง Hash ใหม่สำหรับแต่ละ comment
    comments.each do |comment|
      comment_data = {
        id: comment["id"],
        message: comment["message"],
        created_time: comment["created_time"],
        from: comment["from"] ? {
          id: comment["from"]["id"],
          name: comment["from"]["name"],
        } : nil,
      }

      cf_result = detect_cf_order(comment_data)
    end
    # else
    #   Rails.logger.error "Failed to fetch comments for Facebook Live ID: #{@live_id}, Response: #{response.body}"
    #   []
    # end
  rescue StandardError => e
    Rails.logger.error("Failed to fetch comments for Facebook Live: #{@live_id}, Error: #{e.message}")
    []
  end

  def detect_cf_order(comment_data)
    return nil if comment_data.nil?

    message = comment_data[:message]

    puts "\n====================="
    puts "[FacebookLiveCommentService] ตรวจสอบคอมเมนต์:"
    puts JSON.pretty_generate(comment_data)
    puts "====================="

    # Pattern สำหรับจับ CF ตามด้วยตัวเลข เช่น "CF 123", "CF123", "cf 456"
    cf_pattern = /\b(cf|CF)\s*(\d+)\b/

    match = message.match(cf_pattern)
    if match
      puts "\e[32m[ตรวจพบ CF Order] -> Order Number: #{match[2]}\e[0m"
      order_number = match[2]
      create_order(comment_data.merge(order_number: order_number))
    else
      puts "\e[33m[ไม่พบ CF Order ในข้อความนี้]\e[0m"
      {
        detected: false,
        order_number: nil,
        original_message: message,
      }
    end
  end

  def create_order(data)
    puts "\n---------------------"
    puts "[สร้างออเดอร์ใหม่] Data:"
    puts JSON.pretty_generate(data)
    puts "---------------------"

    # 1. หา Product จาก productCode
    order_number = data[:order_number]
    product = Product.active.find_by(productCode: order_number.to_i)

    unless product
      puts "\e[31m[ไม่พบสินค้า] Product code: #{order_number}\e[0m"
      return nil
    end

    # 2. ใช้ Merchant (User) ที่ส่งมาใน constructor
    unless @user
      puts "\e[31m[ไม่พบ User (merchant)]\e[0m"
      return nil
    end
    puts "\e[36m[ใช้ merchant] #{@user.name} (ID: #{@user.id})\e[0m"

    # 3. ตรวจสอบว่า comment นี้ถูกประมวลผลแล้วหรือไม่
    existing_order = Order.active_for_duplicate_check.find_by(
      facebook_user_id: data[:from][:id],
      order_number: order_number,
      user: @user,
    )

    if existing_order
      puts "\e[33m[พบออเดอร์เดิมแล้ว] Comment #{data[:id]} -> Order: #{existing_order.order_number}\e[0m"
      return existing_order
    end

    # 4. สร้าง Order
    begin
      quantity = 1 # หรือกำหนดค่าเริ่มต้นตามที่ต้องการ
      unit_price = product.productPrice
      total_amount = unit_price * quantity

      order = Order.create!(
        # Required fields
        order_number: "CF#{order_number}",
        product: product,
        user: @user,
        quantity: 1, # หรือกำหนดค่าเริ่มต้นตามที่ต้องการ
        unit_price: unit_price,
        total_amount: total_amount,
        facebook_comment_id: data[:id],
        facebook_user_id: data[:from][:id],

        # Optional fields
        facebook_user_name: data[:from][:name],
        facebook_live_id: @live_id,
        comment_time: Time.parse(data[:created_time]),
      )

      puts "\e[32m[สร้างออเดอร์สำเร็จ] Order: #{order.order_number}\e[0m"

      # 5. ส่งลิงค์ checkout (optional)
      # send_checkout_link(order)

      return order
    rescue ActiveRecord::RecordInvalid => e
      puts "\e[31m[สร้างออเดอร์ไม่สำเร็จ] Validation failed: #{e.message}\e[0m"
      puts "\e[31mValidation errors: #{e.record.errors.full_messages}\e[0m"
      return nil
    rescue StandardError => e
      puts "\e[31m[Unexpected error creating order] #{e.message}\e[0m"
      return nil
    end
  end

  private

  #   def send_checkout_link(order)
  #     checkout_url = order.checkout_url
  #     @comment_id = order.facebook_comment_id # เก็บไว้สำหรับ fallback

  #     reply_message = "✅ ขอบคุณที่สั่งซื้อ #{order.product.productName}
  # 💰 ราคา #{order.total_amount} บาท
  # 🔗 กรุณาคลิกลิงค์นี้เพื่อกรอกข้อมูลและชำระเงิน: #{checkout_url}
  # ⏰ ลิงค์หมดอายุใน 24 ชั่วโมง"

  #     Rails.logger.info "Sending private message to user #{order.facebook_user_id}: #{reply_message}"

  #     # Send Facebook private message instead of public reply
  #     # send_private_message(order.facebook_user_id, reply_message)
  #   end

  # def send_private_message(user_id, message)
  #   return unless @access_token.present?

  #   begin
  #     # ส่งข้อความส่วนตัวผ่าน Facebook Messenger API
  #     response = HTTParty.post("https://graph.facebook.com/v18.0/me/messages",
  #                              body: {
  #                                recipient: { id: user_id },
  #                                message: { text: message },
  #                                access_token: @access_token,
  #                              }.to_json,
  #                              headers: {
  #                                "Content-Type" => "application/json",
  #                              })

  #     if response.success?
  #       Rails.logger.info "Facebook private message sent successfully to user #{user_id}"
  #     else
  #       Rails.logger.error "Facebook private message failed: #{response.body}"
  #     end
  #   rescue StandardError => e
  #     Rails.logger.error "Error sending Facebook private message: #{e.message}"
  #     # Fallback: ถ้าเกิด error ให้ส่งเป็น comment reply แทน
  #     Rails.logger.info "Falling back to comment reply due to error..."
  #   end
  # end
end
