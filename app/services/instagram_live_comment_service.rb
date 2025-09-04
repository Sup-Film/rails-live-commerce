class InstagramLiveCommentService
  attr_reader :live_video_id, :access_token, :user

  def initialize(live_video_id, access_token, user)
    @live_video_id = live_video_id
    @access_token = access_token
    @user = user
  end

  def process_comment(comment_data)
    # รองรับทั้ง Instagram webhook payload format
    comment_id = comment_data["comment_id"] || comment_data["id"]
    comment_text = comment_data["text"]
    commenter_id = comment_data.dig("from", "id")
    commenter_name = comment_data.dig("from", "username") || comment_data.dig("from", "name")
    media_id = comment_data.dig("media", "id")
    parent_id = comment_data["parent_id"] # สำหรับ reply comments

    # ใช้ created_time ถ้ามี (จาก entry.time ที่ map มาแล้ว) ไม่งั้นใช้เวลาปัจจุบัน
    comment_time_iso = begin
      if comment_data["created_time"].present?
        Time.parse(comment_data["created_time"].to_s).iso8601
      else
        Time.current.iso8601
      end
    rescue
      Time.current.iso8601
    end

    Rails.logger.info "Processing Instagram Live comment: #{comment_text} by #{commenter_name}"

    # สร้าง comment data ในรูปแบบเดียวกับ Facebook service
    formatted_comment_data = {
      id: comment_id,
      message: comment_text,
      created_time: comment_time_iso,
      from: {
        id: commenter_id,
        name: commenter_name
      }
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
    Rails.logger.debug "Attempting to create Instagram order: #{data[:id]}"

    message = data[:message].to_s

    # ดึงรหัสสินค้า (เหมือน FacebookLiveCommentService)
    product_codes = Product.active.where(user_id: user.id).pluck(:productCode).compact.map { |c| c.to_s.strip.downcase }.uniq

    if product_codes.empty?
      Rails.logger.warn "No products found for user: #{user.id}"
      return nil
    end

    # ตรวจรหัสที่ยาวสุดก่อน
    product_codes.sort_by! { |c| -c.length }

    # normalize ข้อความเพื่อตรวจ (lowercase)
    message_norm = message.downcase

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

    # ตรวจสอบออเดอร์ซ้ำ (เหมือน FacebookLiveCommentService)
    duplicate_time_window = 30.minutes.ago
    existing_order = Order.where(deleted_at: nil)
                          .where(user: user, order_number: found_code, facebook_user_id: data.dig(:from, :id))
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
      order = Order.create!(
        order_number: "IG#{found_code}", # เพิ่ม prefix IG เพื่อแยกจาก Facebook
        product: product,
        user: user,
        status: :pending,
        quantity: quantity,
        unit_price: unit_price,
        total_amount: total_amount,
        facebook_comment_id: data[:id], # ใช้ field เดิมแต่เก็บ Instagram comment ID
        facebook_user_id: data[:from][:id], # ใช้ field เดิมแต่เก็บ Instagram user ID
        facebook_user_name: data[:from][:name],
        facebook_live_id: live_video_id, # ใช้ field เดิมแต่เก็บ Instagram media ID
        comment_time: Time.parse(data[:created_time])
      )

      Rails.logger.info "Instagram order created: #{order.order_number}"
      return order
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
    if (m = message_norm.match(/(?:^|\s)cf[\s:\-_/]*([0-9]{1,10})(?=\D|$)/i))
      candidate = m[1].to_s
      return candidate if sorted.include?(candidate)
    end

    # สำรอง: เจอรหัสสินค้าเป็นคำเดี่ยวในข้อความ (ยาวก่อน ป้องกัน substring)
    sorted.find do |code|
      message_norm.match?(/\b#{Regexp.escape(code)}\b/)
    end
  end
end
