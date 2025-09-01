# Code Review — Rails Facebook API (Product Management + Live Commerce)

เอกสารนี้สรุปข้อเสนอแนะเชิงปฏิบัติ แยกตามลำดับความสำคัญ พร้อมเหตุผลและแนวทางแก้ไขอย่างเป็นรูปธรรม โดยอ้างอิงไฟล์ในโปรเจกต์ชัดเจนเพื่อให้ลงมือทำได้ทันที

---

## สรุปสั้น ๆ
- ระบบทำได้ดีในเชิงสถาปัตยกรรมแยกชั้น Service/Model/Controller ชัดเจน, มี Credit Ledger แบบ idempotent, รองรับ Facebook Webhook และโฟลว์ Checkout ครบหลัก ๆ
- ยังมีจุดสำคัญที่ควรแก้ทันที: การ hardcode UID ใน Webhook, ฟังก์ชันเรียกใช้ที่ไม่มีจริง, ความปลอดภัย SSL, และการตรวจสอบ/เปรียบเทียบลายเซ็นแบบไม่ปลอดภัย
- แนะนำปรับเส้นทางการเข้าสู่ระบบให้สอดคล้องกัน, ทำให้ API auth สม่ำเสมอ, และจัดระเบียบโค้ด/ชื่อเมธอดตาม Ruby style

---

## High Priority (ควรแก้ก่อน)

### 1) Hardcode UID ใน Webhook (เสี่ยง/ผิดข้อมูลจริง)
- ไฟล์: `app/controllers/facebook_live_webhooks_controller.rb:1`
- ปัจจุบัน: `uid = "2926531014188313"`
- ปัญหา: ใช้ UID ตายตัวเสมอ ทำให้ผูกกับ user เดียวและผิดพลาดใน Production/หลายเพจ
- แนวทางแก้:
  - ดึง UID จาก payload ที่ Facebook ส่งมา (เช่น `entry[x].id` หรือเพจ/ผู้ใช้ที่เป็นแหล่งของ event)
  - รองรับหลาย entry/หลาย user ให้แมปถูกต้อง

ตัวอย่างแนวทาง (ปรับให้เข้ากับรูปแบบ payload จริงของเพจ/แอปคุณ):
```ruby
# app/controllers/facebook_live_webhooks_controller.rb
# แทนที่การ hardcode ด้วยการดึงจาก params
uid = params.dig("entry", 0, "id") # หรือค่าที่เหมาะสมกับ payload
user = User.find_by(uid: uid)
return render json: { error: "User not found" }, status: :not_found unless user
```

---

### 2) เรียกเมธอดที่ไม่มีอยู่จริง (ทำให้เกิด error ทันที)
- ไฟล์: `app/controllers/checkout_controller.rb:1`
- อาการ: `OrderService.complete_order(@order)` ถูกเรียกใน `#complete` แต่เมธอดใน `OrderService` ถูกคอมเมนต์ไว้
- ผลกระทบ: เกิด `NoMethodError` เมื่อผู้ใช้กด “complete”
- แนวทางแก้ (เลือกหนึ่ง):
  1) เพิ่มเมธอดให้ทำงานได้จริงใน `OrderService`:
  ```ruby
  # app/services/order_service.rb
  def self.complete_order(order, payment_info = {})
    return false unless order.present? && order.paid?
    order.update(
      status: "confirmed",
      completed_at: Time.current,
      payment_info: payment_info,
    )
  end
  ```
  2) หรือถ้ายังไม่ใช้ flow นี้ ให้ถอดปุ่ม/เส้นทางออกชั่วคราวเพื่อกันผู้ใช้เรียก

---

### 3) ความปลอดภัย SSL ในการตรวจสลิป (ห้าม VERIFY_NONE ใน Production)
- ไฟล์: `app/services/slip_verify_service.rb:1`
- ปัจจุบัน: `https.verify_mode = OpenSSL::SSL::VERIFY_NONE`
- ปัญหา: ปิดการตรวจสอบใบรับรอง SSL เสี่ยงต่อ MITM/ปลอมแปลงข้อมูล
- แนวทางแก้:
  - เปิด `VERIFY_PEER` และกำหนด CA ที่ไว้ใจได้ หรือสลับไปใช้ HTTP client ที่ตั้งค่า TLS/Timeout ได้ง่าย (Faraday/HTTParty พร้อม timeout/verify)
  - เพิ่ม timeout และจัดการ error ให้ครบถ้วน

ตัวอย่างปรับแบบ Net::HTTP:
```ruby
https = Net::HTTP.new(url.host, url.port)
https.use_ssl = true
https.verify_mode = OpenSSL::SSL::VERIFY_PEER
https.open_timeout = 5
https.read_timeout = 5
# https.ca_file = Rails.root.join("config/ca-certificates.crt") if ต้องระบุ CA เอง
```

---

### 4) OmniAuth double redirect และตรรกะ `changed?` ที่ไม่ถูกต้อง
- ไฟล์: `app/controllers/omniauth_callbacks_controller.rb:1`
- ปัญหา:
  - `update!` บันทึกแล้ว ทำให้ `current_user.changed?` เป็น `false` เสมอ จากนั้นมี `redirect_to` ซ้ำทำให้เสี่ยง `AbstractController::DoubleRenderError`
- แนวทางแก้:
```ruby
auth = request.env["omniauth.auth"]
if User.exists?(provider: auth.provider, uid: auth.uid)
  return redirect_to profile_path, alert: "บัญชี Facebook นี้ถูกเชื่อมต่อ..."
end

current_user.assign_attributes(
  provider: auth.provider,
  uid: auth.uid,
  image: auth.info.image,
  oauth_token: auth.credentials.token,
  oauth_expires_at: auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil,
)

if current_user.changed?
  current_user.save!
  return redirect_to profile_path, notice: "เชื่อมต่อบัญชี Facebook สำเร็จ!"
else
  return redirect_to profile_path, notice: "บัญชีของคุณเชื่อมต่อกับ Facebook อยู่แล้ว"
end
```

---

### 5) API auth ใช้ session กับ `ActionController::API` (อาจทำงานไม่ครบ/ไม่เสถียร)
- ไฟล์: `app/controllers/api/v1/base_controller.rb:1`
- ปัจจุบัน: ใช้ `ActionController::API` + `include ActionController::Cookies` แล้วอ่าน `session[:user_id]`
- ปัญหา: ในสภาพแวดล้อม API-only มักไม่มี session middleware ครบชุด และ frontend ที่เรียก API ควรใช้ token/jwt มากกว่า session
- แนวทางแก้ (เลือกหนึ่ง):
  - สลับ base class เป็น `ApplicationController` ถ้าต้องการ session เดิม
  - หรือ เพิ่ม auth แบบ Token/JWT ผ่าน Header (`Authorization: Bearer ...`) แล้วเลิกผูกกับ session

---

### 6) Payment/Submit Payment flow ยังไม่จบ (โค้ดถูกคอมเมนต์ไว้)
- ไฟล์: `app/controllers/api/v1/orders_controller.rb:1`, `app/jobs/verify_order_payment_job.rb:1`, `app/models/payment.rb:1`
- ปัญหา: endpoint `submit_payment` ตรวจ params แต่ไม่สร้าง/บันทึก `Payment` และไม่ verify จริง (คอมเมนต์ทั้งหมด)
- แนวทางแก้:
  - คืนค่า “debug mode” เฉพาะ dev, และ implement เส้นทางปกติให้ครบ: สร้าง `Payment`, แนบ slip, เรียก verify (mock หรือตัวจริง), อัปเดต `Order` และหักเครดิตด้วย `CreditService.debit`
  - บังคับ POST เท่านั้น และลบ `GET "orders/submit_payment"` ที่ซ้ำซ้อนจาก `routes` (มี route GET เก่าอยู่)

---

## Medium Priority

### 7) เปรียบเทียบ HMAC ควรใช้ secure compare
- ไฟล์: `app/controllers/facebook_live_webhooks_controller.rb:1`
- ปัจจุบัน: `signature_hash == expected_hash`
- ความเสี่ยง: timing attack ในการเทียบสตริง
- แนวทางแก้:
```ruby
provided = signature.split("=").last
expected = OpenSSL::HMAC.hexdigest("sha256", ENV["FACEBOOK_APP_SECRET"], body)
return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
```

### 8) ชื่อเมธอด/สไตล์
- ไฟล์: `app/controllers/facebook_live_webhooks_controller.rb:1`
- ปัจจุบัน: `before_action :verifyRequestSignature` (camelCase)
- แนวทาง: เปลี่ยนเป็น snake_case `:verify_request_signature` และเมธอดชื่อเดียวกัน เพื่อสอดคล้อง Ruby style

### 9) เส้นทางเข้าสู่ระบบไม่สอดคล้องกัน
- ไฟล์: `app/controllers/dashboards_controller.rb:1`, `app/controllers/credits_controller.rb:1`, `app/controllers/pages_controller.rb:1`
- ปัญหา: ใช้ `new_user_session_path` แต่โปรเจกต์ไม่ได้ใช้ Devise (routes กำหนด `login_path`)
- แนวทางแก้: เปลี่ยน redirect ให้ใช้ `login_path`

### 10) Validation ของ User สับสน (presence + allow_blank)
- ไฟล์: `app/models/user.rb:1`
- ปัจจุบัน: `validates :bank_account_number, presence: true, ..., allow_blank: true` และ `:bank_account_name, presence: true, allow_blank: true`
- ปัญหา: `allow_blank: true` ทำให้ presence ไม่ถูกบังคับจริง
- แนวทางแก้:
  - ถ้าต้อง “ไม่บังคับ”: เอา `presence: true` ออก
  - ถ้าต้อง “บังคับ”: เอา `allow_blank: true` ออก

### 11) โค้ด “magic number”/config แข็ง
- ไฟล์: หลายที่เช่น `shipping_cost_cents = 5000` ใน `checkout_controller.rb:1`, `process_held_orders_job.rb:1`, `verify_order_payment_job.rb:1`
- แนวทาง: ย้ายไป ENV/config (`Rails.application.config.x.shipping.default_cost_cents`) หรือสร้าง `ShippingService`

### 12) Pattern การแมตช์คอมเมนต์ → product code
- ไฟล์: `app/services/facebook_live_comment_service.rb:1`
- ปัจจุบัน: ตรวจ code ด้วย regex word boundary จากข้อความทั้งหมด (เสี่ยง false positive)
- แนวทาง:
  - บังคับรูปแบบ เช่น `/(^|\s)cf\s+(\d{1,10})(\s|$)/i` แล้วค่อยตรวจว่ารหัสนั้นมีจริง
  - รองรับคำสะกด/ช่องว่าง/ตัวพิมพ์เล็กใหญ่

### 13) `Order#cancellable?` ไม่สอดคล้องกับ scope `cancellable`
- ไฟล์: `app/models/order.rb:1`
- ปัจจุบัน: scope รวม `pending, paid` แต่เมธอดคืน `status == "pending"`
- แนวทาง: ทำให้ตรงกัน หรือแยก semantic ให้ชัดเจน (เช่น `cancellable_by_buyer?`/`by_seller?`)

---

## Low Priority / Cleanups
- ใช้ `Rails.logger` แทน `puts` ใน service/jobs เพื่อ log ที่เป็นระบบ และเพิ่มระดับ log (info/debug/warn/error)
- จัดระเบียบ error handling ใน jobs ด้วย `retry_on`/`discard_on` แทน rescue กว้าง ๆ
- เพิ่ม timeout/ข้อผิดพลาดให้ `FacebookApiService` (HTTParty) และตั้งค่า BASE_URL ผ่าน ENV
- ใช้ eager loading ในหน้า dashboard หากมี N+1 (เช่น `.includes(:product)`) เมื่อแสดงรายการออเดอร์พร้อมข้อมูลสินค้า
- ปรับ camelCase columns ของ Product (`productName`, `productPrice`) ให้เป็น snake_case ในระยะยาว (ผ่าน migration + ช่วง deprecate)

---

## ความปลอดภัย (เสริม)
- Rack::Attack: เพิ่ม throttle ต่อ IP/User สำหรับ endpoints สำคัญอื่น ๆ และ log โครงสร้างชัดเจน (`config/initializers/rack_attack.rb:1`)
- Webhook GET verify: ใช้ `ENV["FACEBOOK_VERIFY_TOKEN"]` ถูกต้องแล้ว แต่อย่าล็อกค่า verify_token หรือ challenge ลง log ที่เปิดเผยได้
- ควรพิจารณาเซ็นชื่อ response หรือเก็บ `raw_post` สำหรับการดีบักด้วยความระวัง ไม่ log access token/secret

---

## การทดสอบที่ควรมีเพิ่ม
- Webhook signature: happy path + invalid signature (`facebook_live_webhooks_controller`)
- SlipVerifyService: token refresh ก่อนหมดอายุ, timeout, non-200 responses, JSON parsing
- CreditService: idempotency/record lock/concurrent top-up & debit
- CheckoutController: โฟลว์ on_hold → top_up → awaiting_payment → paid
- OmniAuth: กรณีบัญชีเชื่อมแล้ว/ไม่เชื่อม, ความผิดพลาด และป้องกัน double render

---

## Quick Wins (ลงมือได้เร็ว)
1) แก้เส้นทาง `new_user_session_path` → `login_path`
2) เปลี่ยน `verifyRequestSignature` → `verify_request_signature` และใช้ `secure_compare`
3) ลบ GET route ที่ซ้ำของ `orders/submit_payment` และเปิดใช้เฉพาะ POST
4) แก้ `SlipVerifyService` ให้ VERIFY_PEER + timeout
5) ย้าย `shipping_cost_cents` ไป config
6) ปรับ `User` validations ให้ตรงตามความต้องการจริง (บังคับ/ไม่บังคับ)
7) เติม `OrderService.complete_order` หรือซ่อนปุ่ม/เส้นทาง `complete`
8) เลิก hardcode UID ใน Webhook แล้ว map จาก payload จริง

---

## ภาคผนวก: จุดดีที่ทำไว้แล้ว
- ใช้ `CreditLedger` กับ idempotency key และ DB unique index ป้องกันการเติมเงินซ้ำ (`app/models/credit_ledger.rb:1`)
- มี `ProcessHeldOrdersJob` เพื่อปลดออเดอร์เมื่อเครดิตพอ (แนวคิดถูกต้อง) (`app/jobs/process_held_orders_job.rb:1`)
- แยก `FacebookLiveWebhookService`/`FacebookLiveCommentService` ช่วยดูแลความซับซ้อนของ Webhook/Live
- ใช้ `Active Storage` แนบสลิป + validations (`app/models/payment.rb:1`)

---

ถ้าต้องการ ผมสามารถออก PR ย่อย ๆ ตาม Quick Wins ด้านบนให้ทันที หรือโฟกัสไปที่การปิดงาน High Priority ก่อน แล้วค่อยไล่ปรับ Medium/Low ต่อเป็นเฟส ๆ

