class InstagramLiveCommentService
  attr_reader :live_video_id, :access_token, :user

  def initialize(live_video_id, access_token, user)
    @live_video_id = live_video_id
    @access_token = access_token
    @user = user

    # Log เริ่มต้น service
    ApplicationLoggerService.business_event("instagram_live_comment_service_initialized", {
      live_id: @live_video_id,
      user_id: @user&.id,
      has_access_token: @access_token.present?,
    })
  end

  def process_comment(comment_data)
    # ใช้ Indifferent Access เพื่อเข้าถึง key ได้ทั้งแบบ symbol และ string อย่างสะอาด
    data = (comment_data.respond_to?(:to_unsafe_h) ? comment_data.to_unsafe_h : comment_data)
    data = data.is_a?(Hash) ? data.with_indifferent_access : {}

    from = data[:from].is_a?(Hash) ? data[:from].with_indifferent_access : {}
    media = data[:media].is_a?(Hash) ? data[:media].with_indifferent_access : {}

    comment_id = data[:comment_id].presence || data[:id]
    comment_text = (data[:text].presence || data[:message]).to_s
    commenter_id = from[:id]
    commenter_name = from[:username].presence || from[:name]
    media_id = media[:id]
    parent_id = data[:parent_id] # สำหรับ reply comments

    # ใช้ created_time ถ้ามี (จาก entry.time ที่ map มาแล้ว) ไม่งั้นใช้เวลาปัจจุบัน
    comment_time_iso = begin
        if data[:created_time].present?
          Time.parse(data[:created_time].to_s).iso8601
        else
          Time.current.iso8601
        end
      rescue
        Time.current.iso8601
      end

    # สร้าง comment data ในรูปแบบเดียวกับ Facebook service
    formatted_comment_data = {
      id: comment_id,
      message: comment_text,
      created_time: comment_time_iso,
      from: {
        id: commenter_id,
        name: commenter_name,
      },
    }

    # สร้างออเดอร์โดยใช้ create_order method (เหมือน FacebookLiveCommentService)
    cf_result = create_order(formatted_comment_data)
    cf_result
  end

  def fetch_comments
    # ดึง live comments จาก Instagram API (เหมือน FacebookLiveCommentService)
    begin
      response = FacebookApiService.new(access_token).get_instagram_live_comments(live_video_id)

      if response && response["data"]
        created_orders = []
        response["data"].each do |comment|
          cf_result = process_comment(comment)
          created_orders << cf_result if cf_result.present?
        end
        created_orders
      else
        []
      end
    rescue => e
      Rails.logger.error "Failed to fetch Instagram Live comments: #{e.message}"
      []
    end
  end

  # ประมวลผลหลายคอมเมนต์พร้อมกัน (Many)
  # คาดหวังว่าคอมเมนต์ทั้งหมดเป็นของ live_video เดียวกันที่ถูกระบุในตอน initialize
  def process_comments(comments)
    return [] unless comments.is_a?(Array)

    created_orders = []
    comments.each do |comment|
      begin
        result = process_comment(comment)
        created_orders << result if result.present?
      rescue => e
        Rails.logger.error "Failed to process an Instagram comment in batch: #{e.class} - #{e.message}"
      end
    end
    created_orders
  end

  def create_order(data)
    message = data[:message].to_s
    raise ArgumentError, "Empty comment message" if message.blank?

    # ดึงรหัสสินค้า (เหมือน FacebookLiveCommentService)
    product_codes = Product.active.where(user_id: user.id).pluck(:productCode).compact.map { |c| c.to_s.strip.downcase }.uniq

    if product_codes.empty?
      Rails.logger.warn "No products found for user: #{user.id}"
      return nil
    end

    # ตรวจรหัสที่ยาวสุดก่อน
    product_codes.sort_by! { |c| -c.length }
    Rails.logger.debug "User product codes: #{product_codes.join(", ")}"

    # normalize ข้อความเพื่อตรวจ (lowercase)
    message_norm = message.downcase
    Rails.logger.debug "Normalized Instagram message: #{message_norm}"

    # ใช้ parser เดียวกับ FacebookLiveCommentService สำหรับ CF
    found_code = parse_product_code(message_norm, product_codes)
    unless found_code
      Rails.logger.warn "Product not found in Instagram message: #{message}"
      return nil
    end

    product = Product.active.find_by(productCode: found_code.to_i)
    unless product
      Rails.logger.warn "Product not found for code: #{found_code}"
      return nil
    end

    # TODO: ต้องแทนที่ด้วย SkyboxService เพื่อเช็คราคาขนส่ง
    shipping_cost_cents = 5000
    insufficient_credit = !@user.has_sufficient_credit?(shipping_cost_cents)

    if insufficient_credit
      ApplicationLoggerService.warn("credit.insufficient", {
        required_credit_cents: shipping_cost_cents,
        current_balance_cents: @user.credit_balance_cents,
        user_id: @user.id,
      })
      notify_insufficient_credit_once(
        user: @user,
        product: product,
        from: data[:from],
        required_credit_cents: shipping_cost_cents,
      )
    end

    # กันซ้ำให้ตรงกับคอนสเตรนต์ DB: (facebook_comment_id, facebook_user_id, user_id)
    if (existing_by_unique = Order.where(deleted_at: nil).find_by(
          user: user,
          facebook_user_id: data.dig(:from, :id),
          facebook_comment_id: data[:id],
        ))
      Rails.logger.info "Found existing Instagram order by unique key: #{existing_by_unique.id}"
      return existing_by_unique
    end

    # ตรวจสอบออเดอร์ซ้ำ
    duplicate_time_window = 30.minutes.ago
    existing_order = Order.where(deleted_at: nil)
                          .where(user: user, order_number: "IG#{found_code}", facebook_user_id: data.dig(:from, :id))
                          .where(
                            "status IN (:strict_statuses) OR (status = :paid AND created_at > :since)",
                            strict_statuses: [Order.statuses[:pending], Order.statuses[:on_hold_insufficient_credit]],
                            paid: Order.statuses[:paid],
                            since: duplicate_time_window,
                          ).first

    if existing_order
      Rails.logger.info "Found existing Instagram order: #{existing_order.order_number}"
      return existing_order
    end

    begin
      quantity = 1
      unit_price = product.productPrice
      total_amount = unit_price * quantity

      # สร้าง order สำหรับ Instagram (ใช้ fields เดิมแต่เก็บข้อมูล Instagram)
      order_status = insufficient_credit ? :on_hold_insufficient_credit : :pending
      order = Order.create!(
        order_number: "IG#{found_code}",
        product: product,
        user: user,
        status: order_status,
        quantity: quantity,
        unit_price: unit_price,
        total_amount: total_amount,
        facebook_comment_id: data[:id],
        facebook_user_id: data[:from][:id],
        facebook_user_name: data[:from][:name],
        facebook_live_id: live_video_id,
        comment_time: Time.parse(data[:created_time]),
      )

      Rails.logger.info "Instagram order created: #{order.order_number}"
      return order
    rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
      # กัน race condition: อีกโปรเซสอาจสร้างไปก่อน
      Rails.logger.warn "Duplicate detected on create (race). Falling back to lookup: #{e.class}: #{e.message}"
      if (existing = Order.where(deleted_at: nil).find_by(
            user: user,
            facebook_user_id: data.dig(:from, :id),
            facebook_comment_id: data[:id],
          ))
        return existing
      end
      return nil
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create Instagram order: #{e.message}"
      return nil
    rescue StandardError => e
      Rails.logger.error "Unexpected error creating Instagram order: #{e.message}"
      return nil
    end
  end

  private

  # Parser สำหรับข้อความ CF: รองรับ CF123, CF 123, CF-123, CF:123, CF_123, CF/123
  # (เหมือน FacebookLiveCommentService)
  def parse_product_code(message_norm, product_codes)
    sorted = product_codes.sort_by { |c| -c.length }

    # จับรูปแบบ CF123, CF 123, CF-123, CF:123, CF_123, CF/123
    if (m = message_norm.match(%r{(?:^|\s)cf[\s:\-_\/]*([0-9]{1,10})(?=\D|$)}i))
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
    ApplicationLoggerService.info("credit.insufficient.email_sent", { user_id: user.id })
    true
  rescue => e
    ApplicationLoggerService.error("credit.insufficient.email_error", {
      error_class: e.class.name,
      error_message: e.message,
      user_id: user.id,
    })
    false
  end
end
