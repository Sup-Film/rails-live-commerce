# Development Plan - Rails Facebook API System

## Overview

แผนการพัฒนาระบบครบถ้วนตาม UPDATED_SYSTEM_REQUIREMENTS.md โดยเน้นการพัฒนาแบบ
phased approach

---

## 🎯 Phase 1: Monthly Subscription System (Weeks 1-2)

### Week 1: Database & Models

#### Database Migrations

- [ ] Create `subscription_plans` table
  - `id`, `name`, `description`, `price_per_month`, `features` (JSON), `active`,
    `plan_type`
- [ ] Create `user_subscriptions` table
  - `id`, `user_id`, `subscription_plan_id`, `status`, `activated_at`,
    `expires_at`, `paid_amount`, `notes`
- [ ] Create `payment_slips` table
  - `id`, `user_id`, `user_subscription_id`, `amount`, `status`, `slip_image`,
    `notes`, `reference_number`, `payment_date`, `verified_by_id`,
    `verified_at`, `rejection_reason`

#### Models Development

- [ ] `SubscriptionPlan` model
  - Validations, scopes, feature checking methods
- [ ] `UserSubscription` model
  - Status management, expiry checking, renewal logic
- [ ] `PaymentSlip` model
  - Image upload with Active Storage, verification workflow
- [ ] Update `User` model
  - Add subscription associations and helper methods

### Week 2: Core Services & Logic

#### Service Layer

- [ ] `SubscriptionService`
  - Plan activation, renewal processing, expiry management
- [ ] `PaymentProcessor`
  - Slip verification workflow, status updates
- [ ] `NotificationService`
  - Expiry alerts, renewal reminders

#### Access Control

- [ ] Subscription middleware
  - Check active subscription before protected actions
  - Handle expired subscription redirects
- [ ] Admin authorization
  - Role-based access for payment verification

---

## 🚀 Phase 2: Flexible Shipping Framework (Weeks 3-4)

### Week 3: Shipping Infrastructure

#### Database Design

- [ ] Create `shipping_providers` table
  - `id`, `name`, `code`, `config` (JSON), `active`
- [ ] Create `user_shipping_settings` table
  - `id`, `user_id`, `default_provider_id`, `settings` (JSON)
- [ ] Create `shipping_rates` table
  - `id`, `user_id`, `shipping_provider_id`, `zone_name`, `base_rate`,
    `per_kg_rate`, `min_weight`, `max_weight`, `active`

#### Models & Services

- [ ] `ShippingProvider` model
  - Flexible configuration system
- [ ] `UserShippingSettings` model
  - User-specific shipping preferences
- [ ] `ShippingRate` model
  - Zone and weight-based pricing
- [ ] `ShippingCalculator` service
  - Cost calculation logic, provider integration ready

### Week 4: Shipping Configuration UI

#### Controllers & Views

- [ ] Shipping settings management
  - Provider selection, rate configuration
- [ ] Calculator integration
  - Real-time shipping cost preview
- [ ] Admin shipping management
  - Provider setup, rate monitoring

---

## 💳 Phase 3: Enhanced Credit System (Weeks 5-6)

### Week 5: Credit Infrastructure

#### Database & Models

- [ ] Create `user_credits` table
  - `id`, `user_id`, `balance`, `total_topped_up`, `total_used`
- [ ] Create `credit_transactions` table
  - `id`, `user_id`, `transaction_type`, `amount`, `balance_before`,
    `balance_after`, `description`, `reference_type`, `reference_id`,
    `payment_method`, `status`
- [ ] `UserCredit` model with transaction management
- [ ] `CreditTransaction` model with audit trail

#### Core Logic

- [ ] `CreditService`
  - Top-up processing, deduction logic, balance validation
- [ ] Order integration
  - Pre-order credit validation, automatic deduction
- [ ] Notification system
  - Low balance alerts, transaction confirmations

### Week 6: Credit Management & Order Integration

#### Enhanced Order Flow

- [ ] Update `Order` model
  - Add credit validation before creation
  - Automatic shipping cost deduction on confirmation
  - Order blocking when insufficient credit
- [ ] Credit management UI
  - Balance display, transaction history, top-up interface
- [ ] Seller notifications
  - Credit alerts, order blocking notifications

---

## 📝 Phase 4: Enhanced Payment System (Weeks 7-8)

### Week 7: Multi-purpose Payment Processing

#### Database Enhancement

- [ ] Create `payments` table
  - `id`, `user_id`, `payable_type`, `payable_id`, `amount`, `payment_type`,
    `status`
- [ ] Create `payment_verifications` table
  - `id`, `payment_id`, `slip_image`, `status`, `verified_by_id`, `verified_at`,
    `notes`, `rejection_reason`

#### Enhanced Features

- [ ] Polymorphic payment system
  - Support both subscription and credit payments
- [ ] Image processing
  - Slip validation, resizing, secure storage
- [ ] Admin verification dashboard
  - Batch processing, verification workflow

### Week 8: Payment Integration & Testing

#### System Integration

- [ ] Connect payment system with subscriptions and credits
- [ ] Third-party payment preparation
  - API structure for future gateway integration
- [ ] Comprehensive testing
  - Payment flows, verification process, error handling

---

## 🔧 Technical Implementation Details

### Service Layer Architecture

```ruby
# Core Services
- SubscriptionService    # Subscription lifecycle management
- CreditService         # Credit transactions and validation
- PaymentProcessor      # Payment verification and processing
- ShippingCalculator    # Shipping cost calculations
- NotificationService   # System notifications and alerts
- OrderValidator        # Pre-order validation logic
```

### Middleware & Concerns

```ruby
# Access Control
- SubscriptionRequired   # Check active subscription
- CreditValidation      # Validate sufficient credit
- AdminRequired         # Admin-only actions

# Concerns
- Payable              # Polymorphic payment interface
- Notifiable           # Notification handling
- Trackable            # Activity logging
```

### Database Relationships

- User has_many subscriptions, credits, payments, orders
- Subscription belongs_to plan, has_many payments
- Order validates credit before creation
- Payment polymorphic to subscription/credit

---

## 🛡️ Security & Performance Considerations

### Security Measures

- [ ] Input validation and sanitization
- [ ] File upload security (image validation)
- [ ] Admin authorization and audit trails
- [ ] Secure payment data handling
- [ ] Rate limiting for transactions

### Performance Optimization

- [ ] Database indexing strategy
- [ ] Background job processing for heavy operations
- [ ] Caching for frequent queries
- [ ] Image processing optimization

---

## 📊 Testing Strategy

### Unit Testing

- [ ] Model validations and associations
- [ ] Service class logic
- [ ] Helper methods and utilities

### Integration Testing

- [ ] Complete subscription flow
- [ ] Credit system with order integration
- [ ] Payment verification process
- [ ] Shipping calculation accuracy

### System Testing

- [ ] End-to-end user workflows
- [ ] Admin management interfaces
- [ ] Error handling and edge cases
- [ ] Performance under load

---

## 🚀 Deployment & Monitoring

### Deployment Checklist

- [ ] Database migrations
- [ ] Environment configuration
- [ ] Background job setup
- [ ] File storage configuration
- [ ] Admin user setup

### Monitoring & Alerts

- [ ] Subscription expiry monitoring
- [ ] Payment verification delays
- [ ] Credit balance alerts
- [ ] System error tracking
- [ ] Performance metrics

---

## 📈 Future Enhancements (Post-Launch)

### Phase 5+: Advanced Features

- [ ] API integration with real shipping providers
- [ ] Automated payment gateway integration
- [ ] Mobile application development
- [ ] Advanced analytics dashboard
- [ ] Multi-tenant marketplace support

### Scalability Preparations

- [ ] Database optimization and sharding
- [ ] Microservices architecture consideration
- [ ] CDN integration for file storage
- [ ] Load balancing setup
- [ ] Caching strategy enhancement

---

## 📋 Project Timeline Summary

| Phase     | Duration    | Key Deliverables             |
| --------- | ----------- | ---------------------------- |
| Phase 1   | Weeks 1-2   | Monthly Subscription System  |
| Phase 2   | Weeks 3-4   | Flexible Shipping Framework  |
| Phase 3   | Weeks 5-6   | Enhanced Credit System       |
| Phase 4   | Weeks 7-8   | Multi-purpose Payment System |
| **Total** | **8 Weeks** | **Complete System**          |

---

_Last Updated: <%= Time.current.strftime("%d/%m/%Y %H:%M") %>_ _Version: 1.0 -
Initial Development Plan_
