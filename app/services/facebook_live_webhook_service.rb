class FacebookLiveWebhookService
  # @param data [Hash] ข้อมูลที่ได้รับจาก Facebook Live webhook
  attr_reader :data, :access_token

  # สร้างอินสแตนซ์ของ FacebookLiveWebhookService
  def initialize(data, access_token = nil)
    @data = data
    @access_token = access_token
  end

  def process
    return unless data['entry'] # ตรวจสอบว่ามีข้อมูล entry หรือไม่

    # ตรวจสอบว่า data มี key 'entry' และเป็น Array หรือไม่
    data['entry'].each do |entry|
      # Rails.logger.info "Processing entry: #{entry.inspect}"
      process_entry(entry)
    end
  end
  
  private

  def process_entry(entry)
    # ประมวลผล changes ต่างๆ ที่เกี่ยวกับ Live Video
    entry['changes']&.each do |change|
      # Rails.logger.info "Processing change: #{change.inspect}"
      process_live_change(change) if live_video_change?(change)
    end
  end

  def live_video_change?(change)
    change['field'] == 'live_videos'
  end

  def process_live_change(change)
    # Rails.logger.info "Processing live change: #{change.inspect}"
    value = change['value']
    
    case value['status']
    when 'live'
      handle_live_started(value)
    when 'live_stopped'
      handle_live_ended(value)
    when 'vod'
      # handle_live_to_vod(value)
    end
  end

  def handle_live_started(value)
    # FacebookLiveProcessor.new(value).process_live_start
    FacebookLiveCommentService.new(value['id'], access_token).fetch_comments
  end

  def handle_live_ended(value)
    # FacebookLiveProcessor.new(value).process_live_end
    FacebookLiveCommentService.new(value['id'], access_token).fetch_comments
  end

  def handle_live_to_vod(value)
    FacebookLiveProcessor.new(value).process_live_to_vod
  end
end

# process method - entry point หลักสำหรับประมวลผลข้อมูล webhook
# process_entry - ตรวจสอบและประมวลผลแต่ละ entry จาก Facebook
# live_video_change? - ตรวจสอบว่าเป็น Live Video event หรือไม่
# process_live_change - แยกประเภท Live event ตาม status
# แต่ละ handler ส่งต่อไปยัง FacebookLiveProcessor เพื่อประมวลผลต่อ