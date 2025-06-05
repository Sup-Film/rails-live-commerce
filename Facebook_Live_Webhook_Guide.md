# การสร้าง Facebook Live Webhook สำหรับ Rails Application - คู่มือครบครัน

## ภาพรวมของระบบ

ระบบ Facebook Live Webhook จะช่วยให้คุณสามารถรับ Live events จาก Facebook ได้ทันทีเมื่อมีการเริ่ม Live Video รวมถึงรับ Live ID และข้อมูลเพิ่มเติมต่างๆ

### สิ่งที่ระบบจะทำได้:
- รับการแจ้งเตือนเมื่อมีการเริ่ม Live
- รับ Live ID และข้อมูลรายละเอียด
- เก็บสถิติ real-time analytics
- ส่งการแจ้งเตือนผ่านหลายช่องทาง (Email, Slack)
- บันทึกประวัติ Live Videos

---

## ขั้นตอนที่ 1: สร้าง Facebook Live Webhooks Controller

### คำสั่งสร้างไฟล์:
```bash
touch app/controllers/facebook_live_webhooks_controller.rb
```

### โค้ด Controller:
```ruby
class FacebookLiveWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_signature, only: [:receive]

  # GET endpoint สำหรับ Facebook verification
  def verify
    challenge = params['hub.challenge']
    verify_token = params['hub.verify_token']
    
    if verify_token == ENV['FACEBOOK_VERIFY_TOKEN']
      render plain: challenge
    else
      render plain: 'Unauthorized', status: :unauthorized
    end
  end

  # POST endpoint สำหรับรับข้อมูล Live events จาก Facebook
  def receive
    FacebookLiveWebhookService.new(webhook_params).process
    render json: { status: 'ok' }
  rescue StandardError => e
    Rails.logger.error "Facebook Live webhook error: #{e.message}"
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  private

  def webhook_params
    params.require(:object)
    params.permit!
  end

  def verify_signature
    signature = request.headers['X-Hub-Signature-256']
    
    unless signature
      Rails.logger.warn "Couldn't find 'X-Hub-Signature-256' in headers."
      return head :unauthorized
    end
    
    elements = signature.split('=')
    signature_hash = elements[1]
    body = request.body.read
    expected_hash = OpenSSL::HMAC.hexdigest('sha256', ENV['FACEBOOK_APP_SECRET'], body)
    
    unless signature_hash == expected_hash
      Rails.logger.error "Couldn't validate the request signature."
      return head :unauthorized
    end
    
    request.body.rewind
  end
end
```

**หน้าที่ของ Controller:**
- `verify` method: ใช้สำหรับ Facebook webhook verification challenge
- `receive` method: รับ Live events จาก Facebook และส่งต่อไปยัง Service
- `verify_signature`: ตรวจสอบลายเซ็นจาก Facebook เพื่อความปลอดภัย

---

## ขั้นตอนที่ 2: สร้าง Facebook Live Webhook Service

### คำสั่งสร้างไฟล์:
```bash
touch app/services/facebook_live_webhook_service.rb
```

### โค้ด Service:
```ruby
class FacebookLiveWebhookService
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def process
    return unless data['entry']

    data['entry'].each do |entry|
      process_entry(entry)
    end
  end

  private

  def process_entry(entry)
    entry['changes']&.each do |change|
      process_live_change(change) if live_video_change?(change)
    end
  end

  def live_video_change?(change)
    change['field'] == 'live_videos'
  end

  def process_live_change(change)
    value = change['value']
    
    case value['status']
    when 'LIVE'
      handle_live_started(value)
    when 'LIVE_STOPPED'
      handle_live_ended(value)
    when 'VOD'
      handle_live_to_vod(value)
    end
  end

  def handle_live_started(value)
    FacebookLiveProcessor.new(value).process_live_start
  end

  def handle_live_ended(value)
    FacebookLiveProcessor.new(value).process_live_end
  end

  def handle_live_to_vod(value)
    FacebookLiveProcessor.new(value).process_live_to_vod
  end
end
```

**หน้าที่ของ Service:**
- ประมวลผลข้อมูล webhook จาก Facebook
- แยกประเภท Live event ตาม status (LIVE, LIVE_STOPPED, VOD)
- ส่งต่อไปยัง FacebookLiveProcessor เพื่อประมวลผลต่อ

---

## ขั้นตอนที่ 3: สร้าง Facebook Live Processor

### คำสั่งสร้างไฟล์:
```bash
touch app/services/facebook_live_processor.rb
```

### โค้ด Processor:
```ruby
class FacebookLiveProcessor
  attr_reader :live_data

  def initialize(live_data)
    @live_data = live_data
  end

  def process_live_start
    live_video_id = live_data['id']
    
    live_video = FacebookLiveVideo.create!(
      facebook_live_id: live_video_id,
      status: 'LIVE',
      title: live_data['title'],
      description: live_data['description'],
      broadcast_start_time: live_data['broadcast_start_time'],
      permalink_url: live_data['permalink_url'],
      user_id: live_data['from']['id'],
      user_name: live_data['from']['name']
    )

    fetch_additional_live_details(live_video_id)
    notify_live_started(live_video)
    process_live_analytics(live_video_id)
  end

  def process_live_end
    live_video_id = live_data['id']
    live_video = FacebookLiveVideo.find_by(facebook_live_id: live_video_id)

    if live_video
      live_video.update!(
        status: 'LIVE_STOPPED',
        broadcast_end_time: Time.current
      )

      fetch_live_statistics(live_video_id)
      notify_live_ended(live_video)
    end
  end

  def process_live_to_vod
    live_video_id = live_data['id']
    live_video = FacebookLiveVideo.find_by(facebook_live_id: live_video_id)

    if live_video
      live_video.update!(
        status: 'VOD',
        vod_url: live_data['video']['source']
      )

      notify_live_to_vod(live_video)
    end
  end

  private

  def fetch_additional_live_details(live_video_id)
    FacebookLiveDetailService.new(live_video_id).fetch_and_store
  end

  def fetch_live_statistics(live_video_id)
    FacebookLiveStatService.new(live_video_id).fetch_and_store
  end

  def notify_live_started(live_video)
    Rails.logger.info "Live started: #{live_video.facebook_live_id} by #{live_video.user_name}"
    LiveNotificationService.new(live_video).send_start_notification
  end

  def notify_live_ended(live_video)
    Rails.logger.info "Live ended: #{live_video.facebook_live_id}"
    LiveNotificationService.new(live_video).send_end_notification
  end

  def notify_live_to_vod(live_video)
    Rails.logger.info "Live converted to VOD: #{live_video.facebook_live_id}"
    LiveNotificationService.new(live_video).send_vod_notification
  end

  def process_live_analytics(live_video_id)
    FacebookLiveAnalyticsJob.perform_later(live_video_id)
  end
end
```

**หน้าที่ของ Processor:**
- บันทึกข้อมูล Live Video ลงฐานข้อมูล
- เรียกใช้ service เพื่อดึงข้อมูลเพิ่มเติมจาก Facebook API
- ส่งการแจ้งเตือนผ่าน LiveNotificationService
- เริ่ม background job เพื่อเก็บ analytics

---

## ขั้นตอนที่ 4: สร้าง Facebook Live Detail Service

### คำสั่งสร้างไฟล์:
```bash
touch app/services/facebook_live_detail_service.rb
```

### โค้ด Detail Service:
```ruby
class FacebookLiveDetailService
  include HTTParty
  base_uri 'https://graph.facebook.com/v18.0'

  def initialize(live_video_id)
    @live_video_id = live_video_id
    @access_token = ENV['FACEBOOK_PAGE_ACCESS_TOKEN']
  end

  def fetch_and_store
    live_details = fetch_live_details
    store_live_details(live_details) if live_details
  end

  private

  def fetch_live_details
    response = self.class.get(
      "/#{@live_video_id}",
      query: {
        access_token: @access_token,
        fields: 'id,title,description,status,permalink_url,embed_html,secure_stream_url,stream_url,broadcast_start_time,creation_time,live_views,reactions.summary(total_count),comments.summary(total_count)'
      }
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "Failed to fetch live details: #{response.body}"
      nil
    end
  end

  def store_live_details(details)
    live_video = FacebookLiveVideo.find_by(facebook_live_id: @live_video_id)
    return unless live_video

    live_video.update!(
      embed_html: details['embed_html'],
      secure_stream_url: details['secure_stream_url'],
      stream_url: details['stream_url'],
      live_views: details['live_views'],
      total_reactions: details.dig('reactions', 'summary', 'total_count') || 0,
      total_comments: details.dig('comments', 'summary', 'total_count') || 0,
      creation_time: details['creation_time']
    )
  end
end
```

**หน้าที่ของ Detail Service:**
- เรียกใช้ Facebook Graph API เพื่อดึงข้อมูลรายละเอียดของ Live Video
- เก็บข้อมูล reactions, comments, views ลงฐานข้อมูล
- อัพเดทข้อมูล stream URLs และ embed HTML

---

## ขั้นตอนที่ 5: สร้าง Live Notification Service

### คำสั่งสร้างไฟล์:
```bash
touch app/services/live_notification_service.rb
```

### โค้ด Notification Service:
```ruby
class LiveNotificationService
  def initialize(live_video)
    @live_video = live_video
  end

  def send_start_notification
    send_email_notification
    send_slack_notification if ENV['SLACK_WEBHOOK_URL']
    send_push_notification
    create_notification_record('live_started')
  end

  def send_end_notification
    send_email_notification('ended')
    create_notification_record('live_ended')
  end

  def send_vod_notification
    send_email_notification('vod')
    create_notification_record('live_to_vod')
  end

  private

  def send_email_notification(type = 'started')
    LiveNotificationMailer.live_notification(@live_video, type).deliver_now
  end

  def send_slack_notification
    slack_payload = {
      text: "🔴 Live Video Started!",
      attachments: [
        {
          color: "good",
          fields: [
            {
              title: "Title",
              value: @live_video.title,
              short: true
            },
            {
              title: "User",
              value: @live_video.user_name,
              short: true
            },
            {
              title: "Live ID",
              value: @live_video.facebook_live_id,
              short: true
            },
            {
              title: "URL",
              value: @live_video.permalink_url,
              short: false
            }
          ]
        }
      ]
    }

    HTTParty.post(ENV['SLACK_WEBHOOK_URL'], 
      body: slack_payload.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def send_push_notification
    # ส่ง push notification ไปยัง mobile app
  end

  def create_notification_record(event_type)
    Notification.create!(
      notification_type: event_type,
      title: "Live Video #{event_type.humanize}",
      message: "#{@live_video.user_name} #{event_type.gsub('_', ' ')}",
      data: {
        live_video_id: @live_video.facebook_live_id,
        permalink_url: @live_video.permalink_url
      }
    )
  end
end
```

**หน้าที่ของ Notification Service:**
- ส่งการแจ้งเตือนผ่าน Email
- ส่งการแจ้งเตือนไปยัง Slack
- บันทึกประวัติการแจ้งเตือนลงฐานข้อมูล

---

## ขั้นตอนที่ 6: สร้าง Background Job สำหรับ Analytics

### คำสั่งสร้างไฟล์:
```bash
touch app/jobs/facebook_live_analytics_job.rb
```

### โค้ด Analytics Job:
```ruby
class FacebookLiveAnalyticsJob < ApplicationJob
  queue_as :default

  def perform(live_video_id)
    @live_video_id = live_video_id
    collect_live_analytics
  end

  private

  def collect_live_analytics
    live_video = FacebookLiveVideo.find_by(facebook_live_id: @live_video_id)
    return unless live_video&.status == 'LIVE'

    analytics_data = fetch_live_analytics
    store_analytics(analytics_data) if analytics_data

    # Schedule job ต่อไปใน 30 วินาที
    FacebookLiveAnalyticsJob.set(wait: 30.seconds).perform_later(@live_video_id)
  end

  def fetch_live_analytics
    response = HTTParty.get(
      "https://graph.facebook.com/v18.0/#{@live_video_id}",
      query: {
        access_token: ENV['FACEBOOK_PAGE_ACCESS_TOKEN'],
        fields: 'live_views,status,reactions.summary(total_count),comments.summary(total_count)'
      }
    )

    response.success? ? response.parsed_response : nil
  end

  def store_analytics(data)
    FacebookLiveAnalytic.create!(
      facebook_live_id: @live_video_id,
      live_views: data['live_views'],
      total_reactions: data.dig('reactions', 'summary', 'total_count') || 0,
      total_comments: data.dig('comments', 'summary', 'total_count') || 0,
      recorded_at: Time.current
    )
  end
end
```

**หน้าที่ของ Analytics Job:**
- เก็บข้อมูล analytics ทุก 30 วินาทีขณะที่ Live อยู่
- ดึงข้อมูล live_views, reactions, comments จาก Facebook API
- บันทึกข้อมูลลงฐานข้อมูลเพื่อการวิเคราะห์

---

## ขั้นตอนที่ 7: สร้าง Models และ Migrations

### คำสั่งสร้าง Models:

#### สร้าง FacebookLiveVideo Model:
```bash
rails generate model FacebookLiveVideo facebook_live_id:string:index status:string title:text description:text broadcast_start_time:datetime broadcast_end_time:datetime permalink_url:string user_id:string user_name:string embed_html:text secure_stream_url:string stream_url:string live_views:integer total_reactions:integer total_comments:integer creation_time:datetime vod_url:string
```

#### สร้าง FacebookLiveAnalytic Model:
```bash
rails generate model FacebookLiveAnalytic facebook_live_id:string:index live_views:integer total_reactions:integer total_comments:integer recorded_at:datetime
```

#### สร้าง Notification Model:
```bash
rails generate model Notification notification_type:string title:string message:text data:json
```

#### รัน Migration:
```bash
rails db:migrate
```

### โค้ด Models:

#### FacebookLiveVideo Model:
```ruby
class FacebookLiveVideo < ApplicationRecord
  validates :facebook_live_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[LIVE LIVE_STOPPED VOD] }

  has_many :facebook_live_analytics, foreign_key: 'facebook_live_id', primary_key: 'facebook_live_id'

  scope :live_now, -> { where(status: 'LIVE') }
  scope :recent, -> { order(broadcast_start_time: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  def duration
    return nil unless broadcast_start_time
    end_time = broadcast_end_time || Time.current
    end_time - broadcast_start_time
  end

  def is_live?
    status == 'LIVE'
  end
end
```

#### FacebookLiveAnalytic Model:
```ruby
class FacebookLiveAnalytic < ApplicationRecord
  validates :facebook_live_id, presence: true
  validates :recorded_at, presence: true

  belongs_to :facebook_live_video, foreign_key: 'facebook_live_id', primary_key: 'facebook_live_id'

  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_live, ->(live_id) { where(facebook_live_id: live_id) }
end
```

#### Notification Model:
```ruby
class Notification < ApplicationRecord
  validates :notification_type, presence: true
  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
end
```

---

## ขั้นตอนที่ 8: สร้าง Mailer

### คำสั่งสร้าง Mailer:
```bash
rails generate mailer LiveNotificationMailer
```

### โค้ด Mailer:
```ruby
class LiveNotificationMailer < ApplicationMailer
  def live_notification(live_video, type = 'started')
    @live_video = live_video
    @type = type
    
    subject = case type
             when 'started'
               "🔴 Live Video Started: #{@live_video.title}"
             when 'ended'
               "⏹️ Live Video Ended: #{@live_video.title}"
             when 'vod'
               "📹 Live Video Available as VOD: #{@live_video.title}"
             end

    mail(
      to: ENV['NOTIFICATION_EMAIL'],
      subject: subject
    )
  end
end
```

### สร้าง Email Templates:

#### สร้างไฟล์ HTML template:
```bash
touch app/views/live_notification_mailer/live_notification.html.erb
```

#### สร้างไฟล์ Text template:
```bash
touch app/views/live_notification_mailer/live_notification.text.erb
```

--- 

## ขั้นตอนที่ 9: เพิ่ม Routes

### เพิ่มใน config/routes.rb:
```ruby
Rails.application.routes.draw do
  # ...existing code...
  
  # Facebook Live Webhook routes
  get '/facebook/live/webhooks', to: 'facebook_live_webhooks#verify'
  post '/facebook/live/webhooks', to: 'facebook_live_webhooks#receive'
  
  # ...existing code...
end
```

---

## ขั้นตอนที่ 10: ตั้งค่า Environment Variables

### เพิ่มใน .env file:
```bash
# Facebook Configuration
FACEBOOK_VERIFY_TOKEN=your_verify_token_here
FACEBOOK_APP_SECRET=your_app_secret_here
FACEBOOK_PAGE_ACCESS_TOKEN=your_page_access_token_here

# Notification Configuration
NOTIFICATION_EMAIL=admin@yoursite.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

---

## ขั้นตอนที่ 11: การตั้งค่า Facebook App

### ขั้นตอนการตั้งค่าบน Facebook Developer Console:

1. **เปิดใช้งาน Webhooks:**
   - ไปที่ Facebook Developer Console (developers.facebook.com)
   - เลือก App ของคุณ
   - ไปที่เมนู "Webhooks" ในแถบด้านซ้าย

2. **เพิ่ม Webhook URL:**
   ```
   https://yourdomain.com/facebook/live/webhooks
   ```

3. **ตั้งค่า Verify Token:**
   - ใส่ค่าเดียวกับที่ตั้งไว้ใน ENV['FACEBOOK_VERIFY_TOKEN']

4. **เลือก Subscription Fields:**
   - ติ๊กถูกใน `live_videos` field
   - นี่คือ field ที่จะให้ Facebook ส่ง webhook มาเมื่อมี Live Video events

5. **ตั้งค่า Page Subscriptions:**
   - ไปที่ส่วน "Page Subscriptions"
   - เลือก Facebook Page ที่ต้องการติดตาม Live Videos
   - Subscribe กับ `live_videos` field สำหรับ Page นั้น

6. **ตรวจสอบการเชื่อมต่อ:**
   - Facebook จะส่ง verification request มาที่ webhook URL
   - ตรวจสอบ log ว่าได้รับ verification challenge และตอบกลับถูกต้อง

---

## การทดสอบระบบ

### ขั้นตอนการทดสอบ:

1. **ทดสอบ Webhook Verification:**
   ```bash
   curl -X GET "https://yourdomain.com/facebook/live/webhooks?hub.verify_token=YOUR_VERIFY_TOKEN&hub.challenge=CHALLENGE_STRING&hub.mode=subscribe"
   ```

2. **ตรวจสอบ Log:**
   ```bash
   tail -f log/development.log
   ```

3. **ทดสอบ Live Video:**
   - เริ่ม Live Video จาก Facebook Page ที่ตั้งค่าไว้
   - ตรวจสอบ log ว่าได้รับ webhook
   - ตรวจสอบฐานข้อมูลว่ามีการบันทึกข้อมูล Live Video

4. **ตรวจสอบการแจ้งเตือน:**
   - ตรวจสอบว่าได้รับ email แจ้งเตือน
   - ตรวจสอบ Slack notification (ถ้าตั้งค่าไว้)

---

## สรุปการทำงานของระบบ

### Flow การทำงาน:
1. **เมื่อมีคน Live:** Facebook ส่ง webhook มาที่ `/facebook/live/webhooks`
2. **Controller รับข้อมูล:** `FacebookLiveWebhooksController` ตรวจสอบ signature และส่งต่อ
3. **Service ประมวลผล:** `FacebookLiveWebhookService` แยกประเภท event
4. **Processor จัดการ:** `FacebookLiveProcessor` บันทึกข้อมูลและเรียกใช้ service อื่น
5. **ดึงข้อมูลเพิ่ม:** `FacebookLiveDetailService` ดึงข้อมูลละเอียดจาก Facebook API
6. **ส่งการแจ้งเตือน:** `LiveNotificationService` ส่งแจ้งเตือนหลายช่องทาง
7. **เก็บ Analytics:** `FacebookLiveAnalyticsJob` เก็บข้อมูลสถิติ real-time

### ข้อมูลที่ได้รับ:
- **Live ID** (facebook_live_id)
- ชื่อและรายละเอียดของ Live Video
- ข้อมูลผู้ใช้ที่ทำ Live
- URL สำหรับดู Live
- สถิติ real-time (views, reactions, comments)
- Stream URLs สำหรับ embed

### ความปลอดภัย:
- ตรวจสอบ signature จาก Facebook
- ใช้ environment variables สำหรับ sensitive data
- Validate ข้อมูลก่อนบันทึกลงฐานข้อมูล

ระบบนี้จะให้คุณได้รับการแจ้งเตือนและข้อมูลครบถ้วนทันทีที่มีการเริ่ม Live Video บน Facebook Page ที่คุณติดตาม!
