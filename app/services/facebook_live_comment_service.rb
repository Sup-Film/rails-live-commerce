class FacebookLiveCommentService
  def initialize(live_id, access_token = nil, user = nil)
    @live_id = live_id
    @access_token = access_token
    @user = user # ใช้สำหรับหา Merchant ในการสร้าง Order

    # Log เริ่มต้น service
    ApplicationLogger.business_event("facebook_live_comment_service_initialized", {
      live_id: @live_id,
      user_id: @user&.id,
      has_access_token: @access_token.present?,
    })
  end

  def fetch_comments
    start_time = Time.current

    ApplicationLogger.info("Starting to fetch comments", {
      live_id: @live_id,
      user_id: @user&.id,
    })

    unless @user
      puts "\e[31m[ไม่พบ User (merchant)]\e[0m"
      return []
    end

    if @user.products.empty?
      puts "\e[31m[ผู้ขายยังไม่ได้ทำก่ีเพิ่มสินค้าในระบบ] User ID: #{@user.id}\e[0m"
      return []
    end

    url = "https://streaming-graph.facebook.com/#{@live_id}/live_comments?access_token=#{@access_token}&comment_rate=one_per_two_seconds&fields=from{id,name},message,created_time"
    response = HTTParty.get(url)

    if response.success?
      # TODO: Mock response data for testing
      comments = [
        # สร้าง comment สำหรับ productCode 1
        *Array.new(2) { |i| { "id" => "c1_#{i}", "message" => "CF 1", "created_time" => "2023-10-01T12:00:00+0000", "from" => { "id" => "user#{i}", "name" => "User #{i}" } } },
        # สร้าง comment สำหรับ productCode 2
        *Array.new(2) { |i| { "id" => "c2_#{i}", "message" => "CF 2", "created_time" => "2023-10-01T12:01:00+0000", "from" => { "id" => "user#{i + 2}", "name" => "User #{i + 2}" } } },
        # สร้าง comment สำหรับ productCode 3
        *Array.new(2) { |i| { "id" => "c3_#{i}", "message" => "CF 3", "created_time" => "2023-10-01T12:02:00+0000", "from" => { "id" => "user#{i + 10}", "name" => "User #{i + 10}" } } },
        # สร้าง comment สำหรับ productCode 12342
        *Array.new(2) { |i| { "id" => "c4#{i}", "message" => "CF 4", "created_time" => "2023-10-01T12:03:00+0000", "from" => { "id" => "user#{i + 12}", "name" => "User #{i + 12}" } } },
      ].flatten

      comments = response.parsed_response.dig("data") || []
      duration = ((Time.current - start_time) * 1000).round(2)

      ApplicationLogger.performance("fetch_facebook_comments", duration, {
        live_id: @live_id,
        comments_count: comments.size,
        user_id: @user.id,
      })

      # นำข้อมูลใน comment มาวนลูป และทำการสร้าง Hash ใหม่สำหรับแต่ละ comment
      created_orders = []
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
        created_orders << cf_result if cf_result.present?
      end
      created_orders
    else
      ApplicationLogger.error("Failed to fetch Facebook comments", {
        live_id: @live_id,
        status_code: response.code,
        error_body: response.body,
        user_id: @user.id,
      })
      []
    end
  rescue StandardError => e
    duration = ((Time.current - start_time) * 1000).round(2)
    ApplicationLogger.error("Exception in fetch_comments", {
      live_id: @live_id,
      user_id: @user&.id,
      duration_ms: duration,
      error_class: e.class.name,
      error_message: e.message,
      backtrace: e.backtrace&.first(5),
    })
    []
  end

  def create_order(data)
    ApplicationLogger.debug("Attempting to create order", {
      comment_id: data[:id],
      product_codes: data[:product_codes],
      user_id: @user&.id,
    })

    message = data[:message].to_s

    # ดึงรหัสสินค้า, กำจัด nil, แปลงเป็น string และ normalize ให้เป็น lowercase
    product_codes = Product.active.where(user_id: @user.id).pluck(:productCode).compact.map { |c| c.to_s.strip.downcase }.uniq

    if product_codes.empty?
      ApplicationLogger.warn("Product not found for comment", {
        comment_id: data[:id],
        product_codes: product_codes,
        user_id: @user&.id,
      })
      return nil
    end

    # ตรวจรหัสที่ยาวสุดก่อน เพื่อหลีกเลี่ยงการ match แบบ substring ที่ไม่ต้องการ
    product_codes.sort_by! { |c| -c.length }

    # normalize ข้อความเพื่อตรวจ (lowercase)
    message_norm = message.downcase

    # แยก parser ออกเป็นเมธอด เพื่อลด false positives และทดสอบง่าย
    found_code = parse_product_code(message_norm, product_codes)
    unless found_code
      ApplicationLogger.warn("Product not found in message", {
        comment_id: data[:id],
        user_id: @user&.id,
      })
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

    puts "\n---------------------"
    puts "[สร้างออเดอร์ใหม่] Data:"
    puts JSON.pretty_generate(data)
    puts "---------------------"

    # TODO: ต้องแทนที่ด้วย SkyboxService เพื่อเช็คราคาขนส่ง
    shipping_cost_cents = 5000
    insufficient_credit = !@user.has_sufficient_credit?(shipping_cost_cents)

    if insufficient_credit
      ApplicationLogger.warn("credit.insufficient", {
        required_credit_cents: shipping_cost_cents,
        current_balance_cents: @user.credit_balance_cents,
        user_id: @user.id,
      })
      # ส่งอีเมลแจ้งเตือนแบบ throttle เพื่อป้องกันสแปม
      notify_insufficient_credit_once(
        user: @user,
        product: product,
        from: data[:from],
        required_credit_cents: shipping_cost_cents,
      )
    end

    # รวมออเดอร์ที่ถูกพักไว้ด้วย เพื่อกันการสร้างซ้ำในกรณีเครดิตไม่พอ
    # กันซ้ำ: บล็อกสถานะที่ยัง active (pending, on_hold_insufficient_credit) เสมอ
    # และถ้าจ่ายแล้ว อนุญาตสั่งซ้ำหลังเวลาผ่านไป (เช่น 30 นาที)
    duplicate_time_window = 30.minutes.ago
    existing_order = Order.where(deleted_at: nil)
                          .where(user: @user, order_number: found_code, facebook_user_id: data.dig(:from, :id))
                          .where(
                            "status IN (:strict_statuses) OR (status = :paid AND created_at > :since)",
                            strict_statuses: [Order.statuses[:pending], Order.statuses[:on_hold_insufficient_credit]],
                            paid: Order.statuses[:paid],
                            since: duplicate_time_window,
                          ).first

    if existing_order
      puts "\e[33m[พบออเดอร์เดิมแล้ว] Comment #{data[:id]} -> Order: #{existing_order.order_number}\e[0m"
      return existing_order
    end

    begin
      quantity = 1
      unit_price = product.productPrice
      total_amount = unit_price * quantity

      order_status = insufficient_credit ? :on_hold_insufficient_credit : :pending
      order = Order.create!(
        order_number: found_code,
        product: product,
        user: @user,
        status: order_status,
        quantity: quantity,
        unit_price: unit_price,
        total_amount: total_amount,
        facebook_comment_id: data[:id],
        facebook_user_id: data[:from][:id],
        facebook_user_name: data[:from][:name],
        facebook_live_id: @live_id,
        comment_time: Time.parse(data[:created_time]),
      )

      ApplicationLogger.info("order.create.success", {
        order_id: order.id,
        order_number: order.order_number,
        status: order.status,
      })
      return order
    rescue ActiveRecord::RecordInvalid => e
      ApplicationLogger.error("order.create.failed", {
        error_class: e.class.name,
        error_message: e.message,
        validation_errors: e.record.errors.full_messages,
      })
      return nil
    rescue StandardError => e
      ApplicationLogger.error("order.create.unexpected_error", {
        error_class: e.class.name,
        error_message: e.message,
      })
      return nil
    end
  end

  private

  # Parser สำหรับข้อความ CF: รองรับ CF123, CF 123, CF-123, CF:123, CF_123, CF/123
  # พยายามจับ "CF <digits>" ก่อน แล้วค่อย fallback เป็นการค้นหาด้วย word-boundary
  def parse_product_code(message_norm, product_codes)
    sorted = product_codes.sort_by { |c| -c.length }

    # จับรูปแบบ CF123, CF 123, CF-123, CF:123, CF_123, CF/123
    if (m = message_norm.match(/(?:^|\s)cf[\s:\-_/]*([0-9]{1,10})(?=\D|$)/i))
      candidate = m[1].to_s
      return candidate if sorted.include?(candidate)
    end

    # สำรอง: เจอรหัสสินค้าเป็นคำเดี่ยวในข้อความ (ยาวก่อน ป้องกัน substring)
    sorted.find do |code|
      message_norm.match?(/\b#{Regexp.escape(code)}\b/)
    end
  end

  # ส่งอีเมลเตือนเครดิตไม่พอแบบ throttle (จำกัด 1 ครั้ง/ผู้ขาย/30 นาที)
  def notify_insufficient_credit_once(user:, product:, from:, required_credit_cents:)
    cache_key = "insufficient_credit_notified:user:#{user.id}"
    return false if Rails.cache.exist?(cache_key)

    SellerMailer.insufficient_credit_notification(
      user: user,
      order_details: {
        customer_name: from&.dig(:name),
        product_name: product.productName,
        product_code: product.productCode,
      },
      required_credit: required_credit_cents,
    ).deliver_later

    Rails.cache.write(cache_key, true, expires_in: 30.minutes)
    ApplicationLogger.info("credit.insufficient.email_sent", { user_id: user.id })
    true
  rescue => e
    ApplicationLogger.error("credit.insufficient.email_error", {
      error_class: e.class.name,
      error_message: e.message,
      user_id: user.id,
    })
    false
  end

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
