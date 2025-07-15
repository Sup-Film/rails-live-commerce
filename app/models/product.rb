# == Schema Information
#
# Table name: products
#
#  id            :bigint           not null, primary key
#  deleted_at    :datetime
#  image         :string
#  productCode   :integer
#  productDetail :text
#  productName   :string
#  productPrice  :decimal(, )
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_products_on_deleted_at  (deleted_at)
#  index_products_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Product < ApplicationRecord
  # เชื่อม Product กับ User (Product มี owner เป็น User คนหนึ่ง)
  belongs_to :user
  
  # เชื่อมกับ Active Storage สำหรับรูปภาพสินค้า
  has_one_attached :product_image
  has_many :orders

  validates :productName, presence: true
  validates :productDetail, presence: true
  validates :productPrice, presence: true, numericality: true
  validates :productCode, presence: true, numericality: { only_integer: true }, uniqueness: true

  # scope ใช้สำหรับกรองสินค้าที่ไม่ถูกลบ
  scope :active, -> { where(deleted_at: nil) }
  
  # Soft delete method
  def soft_delete!
    transaction do
      update!(deleted_at: Time.current)
      orders.update_all(deleted_at: Time.current)
    end
  end
end
