# SDLC — Rails Facebook API (Live Commerce)

เอกสารวงจรพัฒนาซอฟต์แวร์ (Software Development Life Cycle) สำหรับโปรเจกต์ Rails Facebook API เพื่อใช้เป็นแนวทางร่วมกันของทีม ตั้งแต่งานวางแผน ออกแบบ พัฒนา ทดสอบ ไปจนถึงปล่อยใช้งานและปฏิบัติการ

---

## Overview
- เป้าหมาย: เชื่อมต่อ Facebook/Instagram Live → ดึงคอมเมนต์ → แยกโค้ดสินค้า → สร้างออเดอร์/ออกลิงก์ Checkout → ตรวจเครดิตและค่าส่ง → ตรวจสอบสลิปการโอน → ปิดออเดอร์
- ขอบเขตหลัก: Webhooks + background polling, การซิงก์เพจ/Instagram ผ่าน OAuth, Product & Order lifecycle, Subscription gating + credit ledger, Payment slip verification & debit workflow, การตั้งค่าผู้ให้บริการขนส่ง/บัญชีธนาคาร, Logging & Monitoring

---

## Environments
- Development
  - `letter_opener` เปิดอีเมลในเบราว์เซอร์, Lograge JSON + log level `:debug`
  - Active Storage ใช้ local disk, URL `http://localhost:3000`
  - caching toggle ด้วย `tmp/caching-dev.txt`; `Rails.cache` ใช้ throttle/email guard และหยุด polling job
- Staging
  - mirror production (SSL, background jobs, third-party tokens sandbox)
  - ยังไม่ตั้งค่า → ต้องเตรียม infra/secrets ให้ครบก่อน UAT
- Production
  - `config.force_ssl = true`, logger ส่งออก STDOUT + TaggedLogging, ยังไม่เปิด Lograge
  - Active Storage `:local` (ควรย้ายไป object storage), queue adapter ใช้ค่าเริ่มต้นของ Rails (in-process)
- Secrets/Config: ใช้ Rails Credentials/ENV เช่น `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`, `FACEBOOK_VERIFY_TOKEN`, `FACEBOOK_CALLBACK_URL`, `APP_HOST`, `APP_PROTOCOL`, `MAIL_FROM`
- Third-party tokens: VRich slip verification เก็บในตาราง `third_parties` (token + วันหมดอายุ)

สถานะปัจจุบันจากโปรเจกต์
- Development: `letter_opener`, Lograge JSON, `active_job.verbose_enqueue_logs = true`, Active Storage local (product images + payment slips)
- Production: logger ส่งออก STDOUT + TaggedLogging, `force_ssl` เปิดใช้งาน, ยังไม่เปิด Lograge, Active Storage ยังใช้ local disk, ยังไม่ตั้ง SMTP provider
- Background jobs: queue adapter ยังไม่กำหนด → ใช้ default async/inline; jobs (`PollFacebookLiveCommentsJob`, `ProcessHeldOrdersJob`) ต้องใช้ queue ที่ทนต่อ process restart ใน production
- Slip verify: `SlipVerifyService` ปิด certificate verification (`VERIFY_NONE`) → ต้องเพิ่ม CA ที่ถูกต้องก่อน production
- Cache: dev เปิด/ปิดด้วยไฟล์ `tmp/caching-dev.txt`; prod ต้องใช้ shared store (เช่น Redis) เพื่อ throttle และสื่อสารระหว่าง jobs

---

## Branching & Git
- Main: เสถียรพร้อม deploy
- Feature branches: `feat/*`, `fix/*`, `chore/*`, `docs/*`
- Pull Request: ต้องมีรีวิว ≥1, CI ผ่าน, ลิงก์ issue
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`

---

## Work Items
- Issue Template: ปัญหา/เป้าหมาย, acceptance criteria, screenshots/logs, risks, estimate
- Estimation: ขนาด S/M/L และ dependencies ที่เกี่ยวข้อง

---

## Requirements
- Functional
  - รับคอมเมนต์ Facebook/Instagram Live (webhook + polling) → parse โค้ดสินค้า → สร้างออเดอร์ พร้อมกันซ้ำ/กันเครดิตไม่พอ
  - ซิงก์ Facebook Pages + Instagram Business ผ่าน OmniAuth → เก็บ page access token/instagram_business_account_id สำหรับ webhook ถัดไป
  - Subscription gating และ credit ledger: top up/debit/idempotency, ประมวลผล held orders, บังคับให้ผู้ใช้ active เท่านั้นที่เข้าถึง dashboard/products/credits
  - Checkout + Payment: เก็บข้อมูลลูกค้า, คำนวณค่าส่ง, แจ้งเตือนเครดิตไม่พอด้วย Mailer, ตรวจสลิปผ่าน VRich API, บันทึกสลิป (Active Storage) และกันสลิปซ้ำ
  - Profile management: บัญชีธนาคาร, default shipping provider, การตั้งค่า/รีเซ็ตรหัสผ่าน, Session timeout 30 นาที, API endpoints (`/api/v1/credit/top_up`, `/api/v1/subscription/verify_slip`, `/api/v1/orders/:token/submit_payment`)
- Non‑Functional
  - Latency < 1s (p95) สำหรับ endpoints หลัก; background jobs ต้องทำงานภายใน SLA (เช่น poll ≤15s)
  - Idempotency/consistency สำหรับ credit, slip verification, webhook processing
  - Structured logging (Lograge + `ApplicationLoggerService`) พร้อม context (`request_id`, `user_id`, `order_id`)
  - Security: บังคับ SSL, หลีกเลี่ยงการ log ข้อมูลอ่อนไหว, ป้องกันการเข้าถึง slip/bank data, อธิบายเหตุผลการปิด CSRF ใน API/Webhook
  - Storage: สลิปและรูปสินค้าควรย้ายไป object storage พร้อม lifecycle policy; third-party/page tokens ต้อง rotate

---

## Design
- Authentication & Session
  - Local auth ผ่าน `UsersController` + `UserSessionsController`; `ApplicationController` มี session timeout 30 นาทีและ helper `check_active_subscription?`
  - OmniAuth Facebook (`OmniauthCallbacksController`) เชื่อมบัญชี → sync pages + Instagram ผ่าน `FacebookApiService`
- Controllers
  - Web UI: `DashboardsController`, `ProductsController`, `CheckoutController`, `CreditsController`, `ProfilesController`, `PagesController`, `PasswordResetsController`
  - Webhook/API: `FacebookLiveWebhooksController` (object-type aware: facebook/instagram), `Api::V1::*` (session-based auth, `OrdersController#submit_payment` เปิด public)
- Models
  - Core: `User`, `Product`, `Order`, `Payment`, `CreditLedger`, `Subscription`, `ShippingProvider`, `Page`, `InstagramMedium`, `ThirdParty`
  - Soft delete/idempotency: `Product`/`Order` มี `deleted_at`; `CreditLedger` ใช้ `idempotency_key`; `Page` เก็บ access token + IG account id
- Services
  - Comment ingestion: `FacebookLiveCommentService`, `InstagramLiveCommentService`
  - Webhook orchestration: `FacebookLiveWebhookService`, `InstagramLiveWebhookService`
  - Business logic: `OrderService`, `CreditService`, `SlipVerifyService`, `ApplicationLoggerService`, `FacebookApiService`
- Jobs
  - `PollFacebookLiveCommentsJob` (self-rescheduling, ใช้ cache สำหรับ stop signal)
  - `ProcessHeldOrdersJob` (ย้าย on_hold → awaiting_payment เมื่อเครดิตพอ)
  - `VerifyOrderPaymentJob` (ยังเป็น skeleton สำหรับอ่าน QR/หักเครดิต)
- Mailers
  - `SellerMailer#insufficient_credit_notification`, `PasswordResetMailer#reset_email`
- Config & Integrations
  - ค่าคงที่ (เช่น `shipping_cost_cents = 5000`) ต้องย้ายไป config/business rules
  - Third-party VRich token refresh ผ่าน `SlipVerifyService#get_token`
  - Active Storage ใช้กับ `Product#product_image` และ `Payment#slip`

---

## Implementation
- Naming: ฐานข้อมูลยังใช้ camelCase (`productCode`, `productName`) ให้ซ่อนผ่าน model/helper; โค้ด Ruby ควรใช้ snake_case
- Idempotency: `CreditService` ต้องส่ง `idempotency_key`, webhook/comment ingestion กันซ้ำด้วย unique index + cache (`notify_insufficient_credit_once`)
- Active Storage: รูปสินค้า (`product_image`) และสลิป (`Payment#slip`) ยังเก็บบนดิสก์ → เตรียม S3/Cloud Storage + clean-up policy
- External calls: Graph API (`FacebookLiveCommentService`), VRich (`SlipVerifyService`) ต้องตั้ง timeout/retry และจัดการกรณี response ไม่ใช่ JSON; ปัจจุบันปิด SSL verify ให้แก้ก่อน production
- Background jobs: ตั้ง queue adapter สำหรับ production (Sidekiq/GoodJob ฯลฯ) + เพิ่ม retry strategy; ตอนนี้ใช้ default async/inline
- Feature flags & Config: ค่าขนส่ง 5,000c, polling interval 5/15 วินาที, checkout base URL ใน `Order#checkout_url` ควรถูกย้ายไป ENV/credentials
- Security: `FacebookLiveWebhooksController` ปิด CSRF แต่ตรวจ HMAC (`X-Hub-Signature-256`) → ต้องตั้ง `FACEBOOK_APP_SECRET` และอย่าลืม rewind body

---

## Logging & Observability
- Request logs: Lograge JSON, custom fields (request_id, user_id, params ที่ filter แล้ว)
- Domain logs: ใช้ `ApplicationLogger` (หรือ `app/services/application_logger_service.rb`) + helper อย่าง `business_event`, `performance`, `info/warn/error` เพื่อได้โครงสร้างสม่ำเสมอ
  - ระดับ
    - debug: รายละเอียดดีบัก/ถี่
    - info: เหตุการณ์ธุรกิจปกติ (start/success)
    - warn: ผิดปกติแต่ไปต่อได้ (เครดิตไม่พอ, ช้ากว่า threshold)
    - error: ล้มเหลว/exception/3rd‑party non‑200
  - Context: `request_id`, `user_id`, `live_id`, `order_id`, `duration_ms`, `status_code`
  - Sensitive data: ห้าม log token/email/phone/bank number; ใช้ `config/initializers/filter_parameter_logging.rb`
- สถานะปัจจุบันจากโปรเจกต์
  - Dev: `config.lograge.enabled = true` + `Lograge::Formatters::Json`
  - Prod: ใช้ `ActiveSupport::TaggedLogging` กับ STDOUT; ยังไม่เปิด Lograge
  - Custom logger: มี `app/services/application_logger_service.rb`
  - Filter พารามิเตอร์: `config/initializers/filter_parameter_logging.rb` (ยังกรองคีย์พื้นฐานเท่านั้น)
  - ข้อเสนอแนะ: เพิ่มคีย์อ่อนไหว (เช่น `:password`, `:authorization`, `:access_token`, `:oauth_token`, `:email`, `:phone`, `:bank_account_number`)

- ตัวอย่างอ้างอิงไฟล์
  - `app/services/facebook_live_comment_service.rb`
  - `config/environments/development.rb`, `config/environments/production.rb`

---

## Security
- Webhook: ตรวจ HMAC ด้วย `secure_compare`, ไม่ log secret/token
- TLS: ห้าม `VERIFY_NONE` ใน production; ใช้ `VERIFY_PEER` + timeout
- Session/Auth: แยก web vs API ให้ชัด; ป้องกัน CSRF/redirect loops
- Data exposure: ไม่ log PII, ใช้ parameter filtering ให้ครบถ้วน

สถานะปัจจุบันจากโปรเจกต์
- Webhook: ตรวจ HMAC แล้วด้วย `secure_compare` + ใช้ `FACEBOOK_VERIFY_TOKEN` ใน GET verify
- SlipVerify: ยังตั้ง `VERIFY_NONE` (ควรแก้เป็น `VERIFY_PEER` + timeout)
- เปิดใช้งาน Rack::Attack (middleware + throttling ใน `config/initializers/rack_attack.rb`)
- Password reset: token เก็บเป็น base64 ในตาราง `users` (หมดอายุ 2 ชั่วโมง) → ยังไม่ hash/digest
- Bank data: validation มี แต่ยังไม่ encrypt ในฐานข้อมูล

---

## Testing
- Unit: services (parser/order/credit), slip verify (mock/timeout/non‑200)
- Request/Controller: webhooks (valid/invalid signature), checkout flow
- Jobs: `ProcessHeldOrdersJob`, `VerifyOrderPaymentJob` (happy/failure/retry)
- Factories/Fixtures: deterministic, ชัดเจน
- CI: รัน `rspec` + linters (เติม Rubocop/ERB Lint ได้ตามเหมาะสม)

สถานะปัจจุบันจากโปรเจกต์
- มีสเปค RSpec ครอบคลุมหลายส่วน (jobs, requests, mailers, models) แต่บางไฟล์ยังเป็น `pending` (`spec/jobs/verify_order_payment_job_spec.rb`)
- ยังไม่พบไฟล์ CI ใน repo (ยังไม่ได้ตั้ง GitHub Actions/CircleCI)

---

## Data & Migrations
- Backward compatible, มีแผน rollback
- Soft‑delete: ใช้ `deleted_at`/status ตามโมเดล
- Seeds: เฉพาะ dev/staging ไม่ปน production

---

## CI/CD
- CI steps (อย่างน้อย)
  - bundle install → รัน rspec → linters → security checks (ถ้าเพิ่ม: brakeman/bundler‑audit)
- CD
  - Staging: auto‑deploy จาก main
  - Production: deploy ด้วย tag/release, migrations รันก่อน boot (zero‑downtime ถ้าเป็นไปได้)

---

## Release Management
- Release notes: features, fixes, migration impact, flags
- Versioning: semantic-ish หรือ date‑based
- Rollout: feature flags/เปอร์เซ็นต์ผู้ใช้ถ้าจำเป็น

---

## Incident Management
- Alerts: error rate, job retries, external API failures, latency spikes
- Runbook สั้นๆ
  - Credit ไม่พอ: ตรวจ `ProcessHeldOrdersJob` และยอดเครดิตผู้ขาย
  - Slip verify down: ปิดชั่วคราว/ตั้ง retry/backoff, แจ้งเตือนผู้ใช้
  - Facebook rate limit: ลดอัตราเรียก/เว้นช่วง, เตือนทีม
- Postmortem: RCA, corrective actions, follow‑up PRs

---

## Performance
- ใส่ timeout/metrics ให้ external calls; log duration_ms
- Throttle/Cache: ตัวอย่าง throttling อีเมลเครดิตไม่พอ (ทำแล้วใน `facebook_live_comment_service.rb`)

สถานะปัจจุบันจากโปรเจกต์
- ใช้ `Rails.cache` สำหรับ throttle อีเมลเครดิตไม่พอ (ต้องมี cache store กลางใน prod)
- ป้องกัน N+1: ใช้ `.includes` ในหน้า list/dashboard ที่เหมาะสม
- Poll job ใช้ `FAST_INTERVAL = 5s`, `SLOW_INTERVAL = 15s` และ cache key `polling_job_live_*` → ควรมี metrics เฝ้าดู queue depth/latency

---

## Documentation
- Developer Onboarding: setup, env vars, run jobs, sample tokens
- API/Webhook Docs: endpoints/payload/signatures/ตัวอย่าง
- Operational Playbooks: rotate tokens, respond to failures, deploy steps
- README ปัจจุบันยังเน้น product CRUD → ต้องอัปเดตให้ครอบคลุม live commerce/credit/subscription flows

---

## Definition of Ready (DoR)
- มี acceptance criteria และ test cases เบื้องต้น
- ไม่มี dependency ที่บล็อกการเริ่มงาน
- ประเมินขนาด S/M/L และระบุความเสี่ยง

---

## Definition of Done (DoD)
- โค้ด+ทดสอบผ่าน, logs/metrics ครบ, security reviewed
- เอกสารถูกอัปเดต, PR reviewed & merged, deploy สำเร็จ

---

## Checklists
- Controllers
  - บางเบา, strong params, rescue สั้นๆ, ไม่ทำงานหนักใน request thread
- Services
  - timeout/retry สำหรับ external, log start/finish/error, ไม่มี side‑effects ซ่อนเร้น
- Jobs
  - idempotent, `retry_on`/`discard_on`, log รอบชีวิต, ไม่กลบ exception แบบเงียบ
- Mailers
  - `deliver_later`, มี throttling กันสแปม, template ปลอด PII

---

## Mapping กับโค้ดในโปรเจกต์
- Webhook entrypoint: `app/controllers/facebook_live_webhooks_controller.rb`
- Live comment processing: `app/services/facebook_live_comment_service.rb`, `app/services/instagram_live_comment_service.rb`
- Webhook fan-out: `app/services/facebook_live_webhook_service.rb`, `app/services/instagram_live_webhook_service.rb`
- Order lifecycle: `app/services/order_service.rb`, `app/models/order.rb`
- Credit & Subscription: `app/services/credit_service.rb`, `app/jobs/process_held_orders_job.rb`, `app/models/subscription.rb`
- Payments & slip verify: `app/controllers/api/v1/orders_controller.rb`, `app/services/slip_verify_service.rb`, `app/models/payment.rb`, `app/models/third_party.rb`
- Profile & shipping provider: `app/controllers/profiles_controller.rb`, `app/models/shipping_provider.rb`
- Logging helper: `app/services/application_logger_service.rb`
- Jobs: `app/jobs/poll_facebook_live_comments_job.rb`, `app/jobs/process_held_orders_job.rb`, `app/jobs/verify_order_payment_job.rb`

---

สรุปเส้นทาง (Routes) สำคัญ
- Webhooks: `GET/POST /facebook/live/webhooks` (รองรับทั้ง Facebook และ Instagram)
- Dashboard & Products: `GET /dashboard`, `resources :products`
- Profile & Subscription: `resource :profile`, `get /subscription_required`, `resource :subscription`
- Checkout: `GET /checkout/:token`, `PATCH /checkout/:token`, `GET /checkout/:token/confirmation`, `PATCH /checkout/:token/complete`, `PATCH /checkout/:token/cancel`, `GET /checkout/:token/on_hold`
- Auth & Password reset: `GET/POST /login`, `DELETE /logout`, `GET /auth/:provider/callback`, `resources :password_resets`
- API: `POST /api/v1/orders/:token/submit_payment`, `POST /api/v1/credit/top_up`, `POST /api/v1/subscription/verify_slip`

สถานะ Mailer/Jobs
- Mailer: dev ใช้ `letter_opener`; test ใช้ `:test`; prod ตั้งค่า URL แล้วแต่ยังไม่กำหนด SMTP/provider (`MAIL_FROM` fallback), มี `SellerMailer` และ `PasswordResetMailer`
- Jobs: `PollFacebookLiveCommentsJob`, `ProcessHeldOrdersJob`, `VerifyOrderPaymentJob` (คิว `:default`); ยังไม่ตั้ง `config.active_job.queue_adapter` และยังไม่กำหนด `retry_on/discard_on` (`VerifyOrderPaymentJob` ยังเป็น skeleton)

เวอร์ชัน/ไลบรารี
- Ruby (ใน Gemfile): `3.4.1`; Rails: `~> 7.1.5.1`
- Gems เด่น: `omniauth-facebook`, `httparty`, `lograge` (dev), `letter_opener` (dev), `rspec-rails`, `dotenv-rails`, `rack-attack`, `kaminari`, `active_storage_validations`

สภาพแวดล้อม/ตัวแปร ENV ที่ใช้
- `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`, `FACEBOOK_VERIFY_TOKEN`, `FACEBOOK_CALLBACK_URL`
- `APP_HOST`, `APP_PROTOCOL`, `MAIL_FROM`
- Production secret key (`RAILS_MASTER_KEY` หรือ `RAILS_CREDENTIALS`)
