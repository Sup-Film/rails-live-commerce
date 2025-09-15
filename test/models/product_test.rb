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
#  user_id       :bigint
#
# Indexes
#
#  index_products_on_deleted_at               (deleted_at)
#  index_products_on_user_id                  (user_id)
#  index_products_on_user_id_and_productCode  (user_id,productCode)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class ProductTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
