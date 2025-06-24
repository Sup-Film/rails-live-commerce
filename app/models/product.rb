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
#
class Product < ApplicationRecord
  validates :productName, presence: true
  validates :productDetail, presence: true
  validates :productPrice, presence: true, numericality: true
  validates :productCode, presence: true, numericality: { only_integer: true }, uniqueness: true
end
