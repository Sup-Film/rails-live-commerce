class PollFacebookLiveCommentsJob < ApplicationJob
  queue_as :default

  # โพลทุก interval_seconds วินาที
  # ใช้ Page Access Token
  def perform(live_id:, access_token:, user_id:, since_unix: nil,
              interval_seconds: 5, limit: 50, order: "reverse_chronological",
              filter: "toplevel", live_filter: nil)
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

    # ใช้เวลาคอมเมนต์ล่าสุดใน response เป็นจุดอ้างอิงรอบถัดไป
    next_since = result[:latest_comment_unix] || since_unix

    # จองคิวตัวเองใหม่
    self.class.set(wait: interval_seconds.seconds).perform_later(
      live_id: live_id,
      access_token: access_token,
      user_id: user_id,
      since_unix: next_since,
      interval_seconds: interval_seconds,
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
    self.class.set(wait: interval_seconds.seconds).perform_later(
      live_id: live_id,
      access_token: access_token,
      user_id: user_id,
      since_unix: since_unix,
      interval_seconds: interval_seconds,
      limit: limit,
      order: order,
      filter: filter,
      live_filter: live_filter,
    )
  end
end
