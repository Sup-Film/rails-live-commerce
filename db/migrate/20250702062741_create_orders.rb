class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      # Order basics
      t.string :order_number, null: false     # CF123
      t.integer :status, default: 0           # enum: pending, confirmed, paid, etc.
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, default: 1         # เริ่มต้น 1, แก้ไขได้ใน checkout
      t.decimal :unit_price, precision: 10, scale: 2    # ราคาต่อหน่วย (fixed)
      t.decimal :total_amount, precision: 10, scale: 2  # quantity × unit_price (calculated)

      # Merchant (ผู้ขาย)
      t.references :user, null: false, foreign_key: true  # แม่ค้าที่ live
      t.string :facebook_live_id                          # Live video ID for tracking

      # Facebook integration (ลูกค้า)
      t.string :facebook_comment_id, null: false
      t.string :facebook_user_id, null: false
      t.string :facebook_user_name

      # Customer checkout info (กรอกทีหลัง)
      t.string :customer_name
      t.string :customer_phone
      t.text :customer_address
      t.string :customer_email

      # Checkout token (สำหรับ guest checkout)
      t.string :checkout_token, null: false
      t.datetime :checkout_token_expires_at

      # Timestamps
      t.datetime :comment_time
      t.datetime :checkout_completed_at
      t.datetime :paid_at

      t.timestamps
    end

    # Indexes for performance
    add_index :orders, :order_number, unique: true
    add_index :orders, :facebook_comment_id, unique: true
    add_index :orders, :checkout_token, unique: true
    add_index :orders, [:user_id, :status]                # merchant dashboard queries
    add_index :orders, [:facebook_user_id, :created_at]   # customer order history
    add_index :orders, :checkout_token_expires_at         # cleanup expired tokens
  end
end
