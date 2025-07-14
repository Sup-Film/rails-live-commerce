# == Schema Information
#
# Table name: products
#
#  id            :bigint           not null, primary key
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
#  index_products_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Product < ApplicationRecord
  # เชื่อม Product กับ User (Product มี owner เป็น User คนหนึ่ง)
  belongs_to :user

  validates :productName, presence: true
  validates :productDetail, presence: true
  validates :productPrice, presence: true, numericality: true
  validates :productCode, presence: true, numericality: { only_integer: true }, uniqueness: true
end
