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
    ApplicationLoggerService.info("instagram.webhook.entry.value", { value: value })
    unless value.is_a?(Hash)
      ApplicationLoggerService.warn("instagram.webhook.entry.invalid_value")
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
        ApplicationLoggerService.warn("instagram.webhook.normalize_created_time.failed", {
          error_class: e.class.name,
          error_message: e.message,
        })
        value["created_time"] = Time.current.utc.iso8601
      end
    end

    # ตรวจสอบว่าเป็น live comment เท่านั้น
    if live_comment?(value)
      ApplicationLoggerService.info("instagram.webhook.detected_live_comment")
      process_live_comment_value(value)
    else
      ApplicationLoggerService.info("instagram.webhook.skipped_non_live_comment")
    end
  end

  def process_live_comment_value(value)
    v = value.is_a?(Hash) ? value.with_indifferent_access : {}
    ApplicationLoggerService.info("instagram.webhook.live_comment.value", { value: v })
    comment_id = v[:comment_id] || v[:id]
    comment_text = v[:text]
    commenter_id = v.dig(:from, :id)
    commenter_name = v.dig(:from, :username)
    media_id = v.dig(:media, :id)

    ApplicationLoggerService.info("instagram.webhook.live_comment.summary", {
      media_id: media_id,
      comment_text: comment_text,
      commenter_name: commenter_name,
    })

    # ประมวลผล Instagram Live comment (ส่งต่อไปยัง CommentService แบบ 1:1 ต่อคอมเมนต์)
    begin
      InstagramLiveCommentService.new(media_id, access_token, user).process_comment(v)
    rescue => e
      ApplicationLoggerService.error("instagram.webhook.process_live_comment.failed", {
        error_class: e.class.name,
        error_message: e.message,
      })
      nil
    end
  end

  private

  def live_comment?(value)
    media_product_type = value.dig(:media, :media_product_type)
    media_product_type == "live_video"
  end
end