# SDLC — Rails Facebook API (Live Commerce)

เอกสารวงจรพัฒนาซอฟต์แวร์ (Software Development Life Cycle) สำหรับโปรเจกต์ Rails Facebook API เพื่อใช้เป็นแนวทางร่วมกันของทีม ตั้งแต่งานวางแผน ออกแบบ พัฒนา ทดสอบ ไปจนถึงปล่อยใช้งานและปฏิบัติการ

---

## Overview
- เป้าหมาย: รับคอมเมนต์จาก Facebook Live → แยกรหัสสินค้า → สร้างออเดอร์ → ตรวจเครดิต/ค่าส่ง → ชำระเงินและตรวจสลิป
- ขอบเขตหลัก: Webhooks, Live comment parsing, Order lifecycle, Credit ledger, Payment slip verify, Checkout, Logging/Monitoring

---

## Environments
- Development
  - `letter_opener` เปิดอีเมลในเบราว์เซอร์
  - Lograge JSON + log level `:debug`
  - URL `http://localhost:3000`
- Staging
  - สภาพแวดล้อมเหมือน production ใช้ sandbox tokens
  - ใช้สำหรับ UAT/feature freeze
- Production
  - บังคับ SSL, log JSON, มี alert
  - เปิด background jobs จริง
- Secrets/Config: ใช้ Rails Credentials/ENV เช่น `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`, `FACEBOOK_VERIFY_TOKEN`, `APP_HOST`, `APP_PROTOCOL`

สถานะปัจจุบันจากโปรเจกต์
- Development: ใช้ `letter_opener`, เปิด Lograge JSON, `active_job.verbose_enqueue_logs = true`
- Production: logger ส่งออก STDOUT + TaggedLogging; ยังไม่เปิด Lograge; ตั้งค่า `action_mailer.default_url_options` แล้ว แต่ยังไม่กำหนดผู้ให้บริการอีเมล
- Cache: dev เปิด/ปิดด้วยไฟล์ `tmp/caching-dev.txt`; ควรกำหนด cache store กลางใน prod (เช่น Redis) ให้ throttle ใช้งานได้ข้าม process

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
  - แปลงคอมเมนต์ CF → ออเดอร์, กันซ้ำตามนโยบาย, แจ้งเตือนเครดิตไม่พอแบบ throttle
  - ตรวจสลิป/คิวงาน/อัปเดตสถานะออเดอร์/หักเครดิต
- Non‑Functional
  - Latency < 1s (p95) สำหรับ endpoints หลัก, Error rate < 1%
  - มี audit logs และ structured logging

---

## Design
- Controllers: บางเบา, delegate ไป Service
- Services: แยกความรับผิดชอบชัดเจน
  - `app/services/facebook_live_comment_service.rb` (parser+order), `facebook_api_service.rb`, `order_service.rb`, `slip_verify_service.rb`
- Jobs: งาน async เช่น `process_held_orders_job.rb`, `verify_order_payment_job.rb`
- Config: ค่าธุรกิจเช่น `shipping_cost_cents` เก็บใน `Rails.application.config.x.*` หรือ ENV

---

## Implementation
- Naming: snake_case, ชื่อสื่อความหมาย
- Idempotency: สำหรับ credit ledger, jobs ที่อาจถูกเรียกซ้ำ
- External calls: ใส่ timeout, จัดการ error, พิจารณา retry/backoff ตาม service
- Feature flags: ใช้ ENV/Flipper สำหรับ behavior ที่เสี่ยง

---

## Logging & Observability
- Request logs: Lograge JSON, custom fields (request_id, user_id, params ที่ filter แล้ว)
- Domain logs: ใช้ `ApplicationLogger` (หรือ `app/services/application_logger_service.rb`) เพื่อได้โครงสร้างสม่ำเสมอ
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

---

## Testing
- Unit: services (parser/order/credit), slip verify (mock/timeout/non‑200)
- Request/Controller: webhooks (valid/invalid signature), checkout flow
- Jobs: `ProcessHeldOrdersJob`, `VerifyOrderPaymentJob` (happy/failure/retry)
- Factories/Fixtures: deterministic, ชัดเจน
- CI: รัน `rspec` + linters (เติม Rubocop/ERB Lint ได้ตามเหมาะสม)

สถานะปัจจุบันจากโปรเจกต์
- มีสเปค RSpec ครอบคลุมหลายส่วน (jobs, requests, mailers, models)
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

---

## Documentation
- Developer Onboarding: setup, env vars, run jobs, sample tokens
- API/Webhook Docs: endpoints/payload/signatures/ตัวอย่าง
- Operational Playbooks: rotate tokens, respond to failures, deploy steps

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
- Webhook: `app/controllers/facebook_live_webhooks_controller.rb`
- Comment → Order: `app/services/facebook_live_comment_service.rb`
- Orders API: `app/controllers/api/v1/orders_controller.rb`
- Slip Verify: `app/services/slip_verify_service.rb`
- Logging Helper: `app/services/application_logger_service.rb`
- Jobs: `app/jobs/process_held_orders_job.rb`, `app/jobs/verify_order_payment_job.rb`

---

สรุปเส้นทาง (Routes) สำคัญ
- Webhooks: `GET/POST /facebook/live/webhooks`
- Checkout: `GET /checkout/:token`, `PATCH /checkout/:token`, `GET /checkout/:token/confirmation`, `PATCH /checkout/:token/complete`, `PATCH /checkout/:token/cancel`
- API Orders: `POST /api/v1/orders/:token/submit_payment`
- API Subscription: `POST /api/v1/subscription/verify_slip`
- Auth: `GET/POST /login`, `DELETE /logout`, `GET /auth/:provider/callback`

สถานะ Mailer/Jobs
- Mailer: dev ใช้ `letter_opener`; test ใช้ `:test`; prod ตั้งค่า URL แล้วแต่ยังไม่กำหนด SMTP/provider
- Jobs: มี `ProcessHeldOrdersJob`, `VerifyOrderPaymentJob` (คิว `:default`); ยังไม่ตั้ง `config.active_job.queue_adapter` และยังไม่กำหนด `retry_on/discard_on`

เวอร์ชัน/ไลบรารี
- Ruby (ใน Gemfile): `3.4.1`; Rails: `~> 7.1.5.1`
- Gems เด่น: `omniauth-facebook`, `httparty`, `lograge` (dev), `letter_opener` (dev), `rspec-rails`, `dotenv-rails`, `rack-attack`, `kaminari`, `active_storage_validations`

สภาพแวดล้อม/ตัวแปร ENV ที่ใช้
- `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`, `FACEBOOK_VERIFY_TOKEN`, `APP_HOST`, `APP_PROTOCOL`

อัปเดตตามจริงเมื่อโปรเจกต์พัฒนาไป (source of truth คือโค้ดในไฟล์ที่อ้างอิงด้านบน) หากต้องการเพิ่มภาพรวมสถาปัตยกรรม/sequence diagram ให้แจ้งเพื่อแนบในโฟลเดอร์ `docs/` เพิ่มเติม
