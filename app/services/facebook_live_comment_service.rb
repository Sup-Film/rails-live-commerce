class FacebookLiveCommentService
  def initialize(live_id, access_token = nil)
    @live_id = live_id
    @access_token = access_token
  end

  def fetch_comments
    url = "https://streaming-graph.facebook.com/#{live_id}/live_comments?access_token=#{@access_token}&comment_rate=one_per_two_seconds&fields=from{name,id},message',created_time"
    response = HTTParty.get(url)
    if response.success?
      comments = response.parsed_response["data"] || [] # ถ้ามีข้อมูลใน 'data' ให้ใช้ ถ้าไม่มีก็ใช้เป็น Array ว่าง
      Rails.logger.info "Fetched #{comments.size} comments for Facebook Live ID: #{@live_id}"

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

        # Reply comments
        reply_message = "ขอบคุณสำหรับการ CF กรุณาคลิกที่นี่เพื่อทำการชำระเงิน: "
        HTTParty.post("https://graph.facebook.com/#{comment["id"]}/comments",
                      body: {
                        message: reply_message,
                        access_token: @access_token,
                      })
      end
    else
      Rails.logger.error "Failed to fetch comments for Facebook Live ID: #{@live_id}, Response: #{response.body}"
      []
    end
  rescue StandardError => e
    Rails.logger.error("Failed to fetch comments for Facebook Live: #{@facebook_live.id}, Error: #{e.message}")
    []
  end
end
