# Updated System Requirements & Implementation Plan
## ระบบที่ปรับปรุงตามความต้องการใหม่

---

## 📋 System Requirements Summary

### 1. บัญชี (Subscription System)
- **Payment Model**: จ่ายครั้งเดียว (One-time payment)
- **Access**: Lifetime access หลังจากชำระเงินแล้ว
- **Verification**: Manual verification โดย Admin

### 2. Feature เติมเครดิต (Credit System)
- **Purpose**: เติมเครดิตสำหรับค่าขนส่ง
- **History**: เก็บประวัติการเติมเงินทั้งหมด
- **Order Control**: ถ้าเครดิตไม่พอ → บล็อคการสร้างออเดอร์ + แจ้งเตือนผู้ขาย

### 3. เลือกขนส่ง (Shipping Settings)
- **Provider**: ยังไม่แน่ใจ ต้องรอดูอีกที
- **Design**: สร้างแบบ flexible รองรับ providers ต่างๆ
- **Configuration**: ให้ผู้ขายตั้งค่าขนส่งได้

### 4. ระบบจ่ายเงิน (Payment System)
- **Method**: Upload slip (อัพโหลดสลิป)
- **Verification**: Manual verification
- **Integration**: รองรับ Third Party ในอนาคต

---

## 🚀 Implementation Phases (ลำดับการพัฒนา)

### Phase 1: One-time Subscription System
**Priority: สูงที่สุด** - เป็นพื้นฐานการเข้าถึงระบบ

#### Database Tables
```sql
-- subscription_plans
id, name, description, price, features (JSON), active, plan_type, created_at, updated_at

-- user_subscriptions  
id, user_id, subscription_plan_id, status, activated_at, expires_at (NULL = lifetime), paid_amount, notes, created_at, updated_at

-- payment_slips
id, user_id, user_subscription_id, amount, status, slip_image, notes, reference_number, payment_date, verified_by_id, verified_at, rejection_reason, created_at, updated_at
```

#### Models & Logic
- **SubscriptionPlan**: แผนการใช้งาน (Basic, Premium, Enterprise)
- **UserSubscription**: การสมัครของผู้ใช้ (Lifetime access)
- **PaymentSlip**: หลักฐานการชำระเงิน + Manual verification
- **Access Control**: Middleware ตรวจสอบสมาชิกก่อนเข้าใช้งาน

#### Controllers & Views
- **SubscriptionPlansController**: เลือกแผน + สมัครสมาชิก
- **PaymentSlipsController**: อัพโหลดสลิป + ตรวจสอบสถานะ
- **Admin::PaymentSlipsController**: Admin อนุมัติ/ปฏิเสธการชำระเงิน

---

### Phase 2: Flexible Shipping Framework
**Priority: สูง** - จำเป็นก่อนคำนวณค่าขนส่งใน Credit System

#### Database Tables
```sql
-- shipping_providers
id, name, code, config (JSON), active, created_at, updated_at

-- user_shipping_settings
id, user_id, default_provider_id, settings (JSON), created_at, updated_at

-- shipping_rates
id, user_id, shipping_provider_id, zone_name, base_rate, per_kg_rate, min_weight, max_weight, active, created_at, updated_at
```

#### Models & Logic
- **ShippingProvider**: ข้อมูลบริษัทขนส่ง (แบบ flexible config)
- **UserShippingSettings**: การตั้งค่าขนส่งของผู้ใช้
- **ShippingRate**: อัตราค่าขนส่งตามโซน/น้ำหนัก
- **ShippingCalculator**: Service คำนวณค่าขนส่ง

#### Features
- ตั้งค่าบริษัทขนส่งหลัก
- กำหนดโซนและอัตราค่าขนส่ง
- Calculator แบบ flexible
- รองรับการเพิ่ม API integration ภายหลัง

---

### Phase 3: Credit System with Order Blocking
**Priority: สูง** - Core feature สำหรับควบคุมค่าใช้จ่าย

#### Database Tables
```sql
-- user_credits
id, user_id, balance, total_topped_up, total_used, created_at, updated_at

-- credit_transactions
id, user_id, transaction_type, amount, balance_before, balance_after, description, reference_type, reference_id, payment_method, payment_reference, status, processed_at, created_at, updated_at
```

#### Enhanced Logic
- **Pre-order Validation**: ตรวจสอบเครดิตก่อนสร้าง Order
- **Order Blocking**: บล็อคการสร้าง Order ถ้าเครดิตไม่พอ
- **Seller Notification**: แจ้งเตือนผู้ขายเมื่อเครดิตไม่เพียงพอ
- **Auto-deduction**: หักเครดิตอัตโนมัติเมื่อยืนยันการส่ง

#### Order Integration
```ruby
# Enhanced Order model
class Order < ApplicationRecord
  before_create :validate_seller_credit
  after_update :charge_shipping_cost, if: :should_charge_shipping?
  
  private
  
  def validate_seller_credit
    shipping_cost = calculate_shipping_cost
    
    unless user.has_sufficient_credit?(shipping_cost)
      # ส่งการแจ้งเตือน
      NotificationService.notify_insufficient_credit(user, shipping_cost)
      
      # บล็อคการสร้าง order
      errors.add(:base, "เครดิตไม่เพียงพอสำหรับค่าขนส่ง กรุณาเติมเครดิต")
      throw :abort
    end
  end
  
  def should_charge_shipping?
    saved_change_to_status? && 
    status == 'confirmed' && 
    tracking.present?
  end
  
  def charge_shipping_cost
    shipping_cost = calculate_shipping_cost
    
    CreditService.deduct(
      user,
      shipping_cost,
      reference: self,
      description: "ค่าขนส่งออเดอร์ #{order_number}"
    )
  end
end
```

---

### Phase 4: Manual Payment System with Slip Upload
**Priority: กลาง** - รองรับการเติมเครดิตและชำระ subscription

#### Database Tables
```sql
-- payments
id, user_id, payable_type, payable_id, amount, payment_type, status, created_at, updated_at

-- payment_verifications
id, payment_id, slip_image, status, verified_by_id, verified_at, notes, rejection_reason, created_at, updated_at
```

#### Enhanced Features
- **Multi-purpose Payment**: รองรับทั้ง subscription และ credit top-up
- **Image Processing**: resize, validate รูปสลิป
- **Admin Dashboard**: interface สำหรับ verify payments
- **Notification System**: แจ้งผลการตรวจสอบ
- **Third-party Ready**: เตรียมพร้อมสำหรับ API integration

---

## 🏗️ Technical Architecture

### Database Relationships
```
User
├── UserSubscription (has_many)
├── PaymentSlip (has_many)
├── UserCredit (has_one)
├── CreditTransaction (has_many)
├── UserShippingSettings (has_one)
├── Order (has_many)
└── Payment (has_many)

SubscriptionPlan
└── UserSubscription (has_many)

ShippingProvider
├── UserShippingSettings (has_many)
└── ShippingRate (has_many)

Order
├── CreditTransaction (has_many, as: :reference)
└── Payment (has_many, as: :payable)
```

### Service Layer Architecture
```ruby
# Services
- SubscriptionService    # จัดการ subscription logic
- CreditService         # จัดการ credit transactions
- ShippingCalculator    # คำนวณค่าขนส่ง
- PaymentProcessor      # ประมวลผลการชำระเงิน
- NotificationService   # ส่งการแจ้งเตือน
- OrderValidator        # ตรวจสอบ order ก่อนสร้าง
```

### Middleware & Concerns
```ruby
# Access Control
- SubscriptionRequired   # ตรวจสอบ subscription
- CreditValidation      # ตรวจสอบ credit ก่อน action
- AdminRequired         # สำหรับ admin functions

# Concerns
- Payable              # polymorphic payment interface
- Notifiable           # notification interface
- Trackable            # activity tracking
```

---

## 🎯 Implementation Timeline

### Week 1-2: Phase 1 - Subscription System
- [ ] Database migrations & models
- [ ] Subscription plans setup
- [ ] Payment slip upload & verification
- [ ] Access control middleware
- [ ] Admin verification interface
- [ ] Testing & deployment

### Week 3-4: Phase 2 - Shipping Framework  
- [ ] Shipping provider models
- [ ] User shipping settings
- [ ] Rate configuration system
- [ ] Shipping calculator service
- [ ] Settings UI for sellers
- [ ] Integration testing

### Week 5-6: Phase 3 - Enhanced Credit System
- [ ] Credit models & transactions
- [ ] Order validation logic
- [ ] Credit blocking mechanism
- [ ] Notification system
- [ ] Credit management UI
- [ ] Order integration testing

### Week 7-8: Phase 4 - Payment System Enhancement
- [ ] Multi-purpose payment models
- [ ] Enhanced slip verification
- [ ] Admin dashboard improvements
- [ ] Notification enhancements
- [ ] Third-party preparation
- [ ] Full system testing

---

## 🔐 Security Considerations

### Access Control
- **Subscription-based Access**: ทุก feature ต้องมี subscription
- **Role-based Permissions**: Admin, Seller, Customer roles
- **Credit Security**: ป้องกัน race condition ใน credit transactions

### Data Protection
- **Payment Data**: เข้ารหัสข้อมูลการชำระเงิน
- **File Upload**: validate ประเภทและขนาดไฟล์
- **Admin Verification**: audit trail สำหรับการอนุมัติ

### Business Logic Security
- **Credit Validation**: ตรวจสอบเครดิตแบบ atomic
- **Order Blocking**: ป้องกัน bypass credit validation
- **Rate Limiting**: จำกัดการทำ transactions

---

## 📊 Monitoring & Analytics

### Key Metrics
- **Subscription Conversion**: อัตราการสมัครสมาชิก
- **Credit Usage**: การใช้งานเครดิตเฉลี่ย
- **Order Success Rate**: อัตราสำเร็จของ order creation
- **Payment Verification Time**: เวลาเฉลี่ยในการอนุมัติ

### Alerts & Notifications
- **Low Credit Warning**: แจ้งเตือนเมื่อเครดิตใกล้หมด
- **Payment Verification**: แจ้งผลการตรวจสอบการชำระเงิน
- **System Issues**: แจ้งเตือน admin เมื่อมีปัญหา
- **Usage Statistics**: รายงานการใช้งานประจำเดือน

---

## 🚀 Future Enhancements

### Phase 5+: Advanced Features
- **API Integration**: เชื่อมต่อกับ shipping providers จริง
- **Automated Payments**: payment gateway integration
- **Mobile App**: mobile application
- **Advanced Analytics**: business intelligence dashboard
- **Multi-tenant**: รองรับหลาย marketplace

### Scalability Considerations
- **Database Optimization**: indexing และ query optimization
- **Background Jobs**: async processing สำหรับ heavy tasks
- **Caching Strategy**: Redis caching สำหรับ frequent queries
- **Load Balancing**: เตรียมพร้อมสำหรับ traffic สูง

---

## 📝 Development Notes

### Dependencies Between Phases
1. **Phase 1 → Phase 2**: ต้องมี subscription ก่อนใช้ shipping settings
2. **Phase 2 → Phase 3**: ต้องมี shipping cost calculation ก่อนหัก credit
3. **Phase 1,3 → Phase 4**: payment system รองรับทั้ง subscription และ credit

### Risk Mitigation
- **Start Simple**: เริ่มด้วย manual processes ก่อน automate
- **Incremental Development**: แต่ละ phase ทำให้เสร็จก่อนไป phase ถัดไป
- **Testing Strategy**: unit tests, integration tests, และ manual testing
- **Rollback Plan**: เตรียม rollback strategy สำหรับแต่ละ deployment

### Performance Considerations
- **Database Indexing**: index ที่จำเป็นสำหรับ queries ที่ใช้บ่อย
- **N+1 Queries**: ใช้ includes/joins เพื่อป้องกัน N+1 problems
- **Image Processing**: background job สำหรับ image processing
- **Credit Calculations**: optimize credit validation queries

---

*อัพเดทล่าสุด: <%= Time.current.strftime("%d/%m/%Y %H:%M") %>*
*Version: 2.0 - Updated based on requirements clarification*