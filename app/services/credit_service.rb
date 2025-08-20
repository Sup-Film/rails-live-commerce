class CreditService
  # Error class เฉพาะสำหรับ Service นี้
  class InsufficientCreditError < StandardError; end
  class IdempotencyKeyInUseError < StandardError; end

  # Public Class Methods

  # เติมเครดิต
  def self.top_up(user:, amount_cents:, idempotency_key:, reference: nil, notes: nil)
    add_entry(
      user: user,
      entry_type: :top_up,
      amount_cents: amount_cents.abs, # ใช้ค่าบวกเสมอ
      idempotency_key: idempotency_key,
      reference: reference,
      notes: notes,
    )
  end

  # หักเครดิต
  def self.debit(user:, amount_cents:, idempotency_key:, reference: nil, notes: nil)
    add_entry(
      user: user,
      entry_type: :debit,
      amount_cents: -amount_cents.abs, # ใช้ค่าลบเสมอ
      idempotency_key: idempotency_key,
      reference: reference,
      notes: notes,
    )
  end

  # Private Class Methods

  private_class_method
  def self.add_entry(user:, entry_type:, amount_cents:, idempotency_key:, reference:, notes:)
    # ใช้ DB Transaction เพื่อความปลอดภัยของข้อมูล
    ActiveRecord::Base.transaction do
      # Lock record ของ User เพื่อป้องกัน Race Condition
      user.lock!

      # ตรวจสอบ Idempotency Key
      if CreditLedger.exists?(idempotency_key: idempotency_key)
        raise IdempotencyKeyInUseError, "Idempotency key '#{idempotency_key}' has already been used."
      end

      current_balance = user.credit_balance_cents
      new_balance = current_balance + amount_cents

      # ตรวจสอบว่าเครดิตไม่พอ (กรณีหักเงิน)
      if new_balance.negative?
        raise InsufficientCreditError, "Insufficient credit. Required: #{amount_cents.abs}, Available: #{current_balance}"
      end

      # สร้างบันทึกใน Ledger
      CreditLedger.create!(
        user: user,
        entry_type: entry_type,
        amount_cents: amount_cents,
        balance_after_cents: new_balance,
        idempotency_key: idempotency_key,
        reference: reference,
        notes: notes,
      )
    end
  rescue ActiveRecord::RecordNotUnique
    # เกิดขึ้นเมื่อมีคนพยายามใช้ idempotency_key เดียวกันพร้อมกัน
    raise IdempotencyKeyInUseError, "Idempotency key '#{idempotency_key}' has already been used."
  end
end
