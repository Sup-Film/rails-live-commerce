class UpdateOrderIndexes < ActiveRecord::Migration[7.1]
  def up
    # ลบ unique indexes ที่ไม่ควรเป็น unique
    remove_index :orders, :order_number
    remove_index :orders, :facebook_comment_id
    
    # เพิ่ม index ใหม่ที่ไม่ unique สำหรับ order_number
    add_index :orders, :order_number
    
    # เพิ่ม composite unique index สำหรับป้องกัน comment ซ้ำต่อ user เดียวกัน
    add_index :orders, [:facebook_comment_id, :facebook_user_id, :user_id], 
              unique: true, 
              name: 'index_orders_on_comment_and_users'
  end
  
  def down
    # กลับไปเป็น unique indexes เดิม
    remove_index :orders, :order_number
    remove_index :orders, name: 'index_orders_on_comment_and_users'
    
    add_index :orders, :order_number, unique: true
    add_index :orders, :facebook_comment_id, unique: true
  end
end
