class FacebookLiveWebhookService
  # @param data [Hash] ข้อมูลที่ได้รับจาก Facebook Live webhook
  attr_reader :data, :access_token, :user

  # สร้างอินสแตนซ์ของ FacebookLiveWebhookService
  def initialize(data, access_token = nil, user)
    @data = data
    @access_token = access_token
    @user = user
  end

  def process
    return unless data["entry"] # ตรวจสอบว่ามีข้อมูล entry หรือไม่

    data["entry"].each do |entry|
      # Rails.logger.info "Processing entry: #{entry.inspect}"
      process_entry(entry)
    end
  end

  private

  def process_entry(entry)
    # ประมวลผล changes ต่างๆ ที่เกี่ยวกับ Live Video
    entry["changes"]&.each do |change|
      # Rails.logger.info "Processing change: #{change.inspect}"
      process_live_change(change) if live_video_change?(change)
    end
  end

  def live_video_change?(change)
    change["field"] == "live_videos"
  end

  def process_live_change(change)
    # Rails.logger.info "Processing live change: #{change.inspect}"
    value = change["value"]
    live_id = value["id"]
    cache_key = "polling_job_live_#{live_id}"

    case value["status"]
    when "live"
      Rails.cache.write(cache_key, "run", expires_in: 24.hours)
      handle_live_started(value)
    when "live_stopped"
      Rails.cache.write(cache_key, "stop", expires_in: 1.hour)
      ApplicationLoggerService.info("live_video.stopped", { live_id: live_id, user_id: user.id })
    end
  end

  def handle_live_started(value)
    # ดึงครั้งแรกทันที เพื่อกันพลาดคอมเมนต์ช่วงเริ่มไลฟ์
    initial_result = FacebookLiveCommentService
      .new(value["id"], access_token, user)
      .fetch_comments(limit: 50, filter: "toplevel", live_filter: "stream")

    # ตั้งค่า since_unix จากเวลาคอมเมนต์ล่าสุดใน response (ถ้าไม่มี ใช้เวลาปัจจุบัน)
    since_unix = initial_result[:latest_comment_unix] || Time.current.to_i

    PollFacebookLiveCommentsJob.perform_later(
      live_id: value["id"],
      access_token: access_token,
      user_id: user.id,
      since_unix: since_unix,
      limit: 50,
      filter: "toplevel",
      live_filter: "stream",
    )
  end
end

# process method - entry point หลักสำหรับประมวลผลข้อมูล webhook
# process_entry - ตรวจสอบและประมวลผลแต่ละ entry จาก Facebook
# live_video_change? - ตรวจสอบว่าเป็น Live Video event หรือไม่
# process_live_change - แยกประเภท Live event ตาม status
# แต่ละ handler ส่งต่อไปยัง FacebookLiveProcessor เพื่อประมวลผลต่อ
