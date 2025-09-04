class InstagramLiveWebhookService
  attr_reader :data, :access_token, :user

  def initialize(data, access_token, user)
    @data = data
    @access_token = access_token
    @user = user
  end

  def process
    payload = @data

    # Support both top-level Array (per FB/IG webhook docs) and single Hash
    objects = payload.is_a?(Array) ? payload : [payload]
    objects.each do |obj|
      entries = obj["entry"] || obj[:entry]
      next unless entries.is_a?(Array)
      entries.each do |entry|
        process_entry(entry)
      end
    end
  end

  def process_entry(entry)
    value = entry["value"] || entry[:value]
    Rails.logger.info "Processing Instagram webhook entry value: #{value.inspect}"
    unless value.is_a?(Hash)
      Rails.logger.warn "Invalid entry value, skipping"
      return
    end

    # เติม created_time ถ้ายังไม่มี (support ms/s epoch or string)
    if value["created_time"].blank? && entry["time"].present?
      begin
        ts = entry["time"]
        if ts.is_a?(Numeric)
          epoch = ts > 1_000_000_000_000 ? ts / 1000.0 : ts
          value["created_time"] = Time.at(epoch).utc.iso8601
        else
          value["created_time"] = Time.parse(ts.to_s).utc.iso8601
        end
      rescue => e
        Rails.logger.warn "Failed to normalize created_time: #{e.class} - #{e.message}"
        value["created_time"] = Time.current.utc.iso8601
      end
    end

    # ตรวจสอบว่าเป็น live comment เท่านั้น
    if live_comment?(value)
      process_live_comment_value(value)
    else
      Rails.logger.info "Skipping non-live Instagram comment"
    end
  end

  def process_live_comment_value(value)
    Rails.logger.info "Instagram Live comment value: #{value.inspect}"
    comment_id = value["comment_id"] || value["id"]
    comment_text = value["text"]
    commenter_id = value.dig("from", "id")
    commenter_name = value.dig("from", "username")
    media_id = value.dig("media", "id")

    Rails.logger.info "Instagram Live comment on media #{media_id}: #{comment_text} by #{commenter_name}"

    # ประมวลผล Instagram Live comment (ส่งต่อไปยัง CommentService แบบ 1:1 ต่อคอมเมนต์)
    begin
      InstagramLiveCommentService.new(media_id, access_token, user).process_comment(value)
    rescue => e
      Rails.logger.error "Failed to process Instagram Live comment: #{e.class} - #{e.message}"
      nil
    end
  end

  private

  def live_comment?(value)
    # ตรวจสอบว่าเป็น live_video เท่านั้น
    media_product_type = value.dig("media", "media_product_type")
    media_product_type == "live_video"
  end
end
