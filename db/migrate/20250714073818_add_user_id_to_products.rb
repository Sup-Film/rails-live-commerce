# db/migrate/20250714073818_add_user_id_to_products.rb
class AddUserIdToProducts < ActiveRecord::Migration[7.1]
  def change
    # เพิ่ม user_id column โดยอนุญาตให้ null ได้ก่อน
    add_reference :products, :user, null: true, foreign_key: true
    
    # หา user คนแรกเพื่อใช้เป็น default owner สำหรับ products เดิม
    first_user = User.first
    
    if first_user
      # อัพเดต products ที่ไม่มี user_id ให้มี owner เป็น user คนแรก
      Product.where(user_id: nil).update_all(user_id: first_user.id)
      
      # เปลี่ยน column เป็น null: false หลังจากมีข้อมูลครบแล้ว
      change_column_null :products, :user_id, false
    end
  end
end
