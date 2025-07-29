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
      # สร้าง comment สำหรับ productCode 1
      *Array.new(5) { |i| { "id" => "c1_#{i}", "message" => "CF 1", "created_time" => "2023-10-01T12:00:00+0000", "from" => { "id" => "user#{i}", "name" => "User #{i}" } } },
      # สร้าง comment สำหรับ productCode 2
      *Array.new(5) { |i| { "id" => "c2_#{i}", "message" => "CF 2", "created_time" => "2023-10-01T12:01:00+0000", "from" => { "id" => "user#{i + 5}", "name" => "User #{i + 5}" } } },
      # สร้าง comment สำหรับ productCode 3
      *Array.new(5) { |i| { "id" => "c3_#{i}", "message" => "CF 3", "created_time" => "2023-10-01T12:02:00+0000", "from" => { "id" => "user#{i + 10}", "name" => "User #{i + 10}" } } },
      # สร้าง comment สำหรับ productCode 12345
      *Array.new(5) { |i| { "id" => "c12345_#{i}", "message" => "CF 12345", "created_time" => "2023-10-01T12:03:00+0000", "from" => { "id" => "user#{i + 15}", "name" => "User #{i + 15}" } } },
    ].flatten

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

      cf_result = create_order(comment_data)
    end
    # else
    #   Rails.logger.error "Failed to fetch comments for Facebook Live ID: #{@live_id}, Response: #{response.body}"
    #   []
    # end
  rescue StandardError => e
    Rails.logger.error("Failed to fetch comments for Facebook Live: #{@live_id}, Error: #{e.message}")
    []
  end

  def create_order(data)
    puts "\n---------------------"
    puts "[สร้างออเดอร์ใหม่] Data:"
    puts JSON.pretty_generate(data)
    puts "---------------------"

    message = data[:message].to_s
    product_codes = Product.active.pluck(:productCode).map(&:to_s)
    found_code = product_codes.find { |code| message.include?(code) }

    unless found_code
      puts "\e[31m[ไม่พบสินค้าในข้อความ] Product codes: #{product_codes.join(", ")}\e[0m"
      return nil
    end

    product = Product.active.find_by(productCode: found_code.to_i)
    unless product
      puts "\e[31m[ไม่พบสินค้า] Product code: #{found_code}\e[0m"
      return nil
    end

    unless @user
      puts "\e[31m[ไม่พบ User (merchant)]\e[0m"
      return nil
    end
    puts "\e[36m[ใช้ merchant] #{@user.name} (ID: #{@user.id})\e[0m"

    existing_order = Order.active_for_duplicate_check.find_by(
      facebook_user_id: data[:from][:id],
      order_number: found_code,
      user: @user,
    )

    if existing_order
      puts "\e[33m[พบออเดอร์เดิมแล้ว] Comment #{data[:id]} -> Order: #{existing_order.order_number}\e[0m"
      return existing_order
    end

    begin
      quantity = 1
      unit_price = product.productPrice
      total_amount = unit_price * quantity

      order = Order.create!(
        order_number: found_code,
        product: product,
        user: @user,
        quantity: quantity,
        unit_price: unit_price,
        total_amount: total_amount,
        facebook_comment_id: data[:id],
        facebook_user_id: data[:from][:id],
        facebook_user_name: data[:from][:name],
        facebook_live_id: @live_id,
        comment_time: Time.parse(data[:created_time]),
      )

      puts "\e[32m[สร้างออเดอร์สำเร็จ] Order: #{order.order_number}\e[0m"
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
