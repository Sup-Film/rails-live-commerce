class PollFacebookLiveCommentsJob < ApplicationJob
  queue_as :default

  FAST_INTERVAL = 5.seconds
  SLOW_INTERVAL = 15.seconds

  # โพลทุก interval_seconds วินาที
  # ใช้ Page Access Token
  def perform(live_id:, access_token:, user_id:, since_unix: nil,
              limit: 50, order: "reverse_chronological",
              filter: "toplevel", live_filter: nil)
    # ตรวจสัญญาณหยุดก่อนทำงานใด ๆ
    cache_key = "polling_job_live_#{live_id}"
    if Rails.cache.read(cache_key) == "stop"
      ApplicationLoggerService.info("polling.stopped", { live_id: live_id, reason: "Live video ended." })
      return
    end

    user = User.find_by(id: user_id)
    return unless user

    svc = FacebookLiveCommentService.new(live_id, access_token, user)

    # ดึงคอมเมนต์รอบนี้ พร้อมผลสรุปเวลาคอมเมนต์ล่าสุด
    result = svc.fetch_comments(
      since_unix: since_unix,
      limit: limit,
      order: order,
      filter: filter,
      live_filter: live_filter,
    )

    comments_found = result[:comments].present?
    # ใช้เวลาคอมเมนต์ล่าสุดใน response เป็นจุดอ้างอิงรอบถัดไป
    next_since = result[:latest_comment_unix] || since_unix

    next_interval = comments_found ? FAST_INTERVAL : SLOW_INTERVAL

    ApplicationLoggerService.info("polling.schedule_next", {
      live_id: live_id,
      comments_found: comments_found,
      next_poll_in_seconds: next_interval,
    })

    # จองคิวตัวเองใหม่
    self.class.set(wait: next_interval).perform_later(
      live_id: live_id,
      access_token: access_token,
      user_id: user_id,
      since_unix: next_since,
      limit: limit,
      order: order,
      filter: filter,
      live_filter: live_filter,
    )
  rescue => e
    ApplicationLoggerService.error("poll_live_comments.failed", {
      error_class: e.class.name,
      error_message: e.message,
      live_id: live_id,
      user_id: user_id,
    })
    # พังก็ยังต่อคิวใหม่ เพื่อไม่หยุดถาวร
    self.class.set(wait: FAST_INTERVAL).perform_later(
      live_id: live_id,
      access_token: access_token,
      user_id: user_id,
      since_unix: since_unix,
      limit: limit,
      order: order,
      filter: filter,
      live_filter: live_filter,
    )
  end
end
