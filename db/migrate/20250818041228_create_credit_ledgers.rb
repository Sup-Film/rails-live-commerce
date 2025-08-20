class CreateCreditLedgers < ActiveRecord::Migration[7.1]
  def change
    # สร้างตาราง credit_ledgers
    create_table :credit_ledgers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :entry_type, null: false # ประเภทรายการ: top_up, debit, adjust
      t.integer :amount_cents, null: false, default: 0 # จำนวนเงิน (หน่วยเป็น cent เพื่อความแม่นยำ)
      t.integer :balance_after_cents, null: false # ยอดคงเหลือหลังทำรายการ
      t.string :idempotency_key, null: false # Key ป้องกันการทำรายการซ้ำ
      t.references :reference, polymorphic: true, index: true # อ้างอิงไปยัง Model อื่นๆ เช่น Payment, Order
      t.text :notes

      t.timestamps
    end

    # เพิ่ม Indexes ที่สำคัญเพื่อประสิทธิภาพในการค้นหา
    add_index :credit_ledgers, :entry_type
    add_index :credit_ledgers, :idempotency_key, unique: true # UNIQUE index สำหรับป้องกันการซ้ำ
  end
end
