# == Schema Information
#
# Table name: orders
#
#  id                        :bigint           not null, primary key
#  checkout_completed_at     :datetime
#  checkout_token            :string           not null
#  checkout_token_expires_at :datetime
#  comment_time              :datetime
#  customer_address          :text
#  customer_email            :string
#  customer_name             :string
#  customer_phone            :string
#  deleted_at                :datetime
#  facebook_user_name        :string
#  notes                     :text
#  order_number              :string           not null
#  paid_at                   :datetime
#  quantity                  :integer          default(1)
#  ref                       :string
#  status                    :integer          default("pending")
#  total_amount              :decimal(10, 2)
#  tracking                  :string
#  unit_price                :decimal(10, 2)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  facebook_comment_id       :string           not null
#  facebook_live_id          :string
#  facebook_user_id          :string           not null
#  product_id                :bigint           not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_orders_on_checkout_token                   (checkout_token) UNIQUE
#  index_orders_on_checkout_token_expires_at        (checkout_token_expires_at)
#  index_orders_on_comment_and_users                (facebook_comment_id,facebook_user_id,user_id) UNIQUE
#  index_orders_on_deleted_at                       (deleted_at)
#  index_orders_on_facebook_user_id_and_created_at  (facebook_user_id,created_at)
#  index_orders_on_order_number                     (order_number)
#  index_orders_on_product_id                       (product_id)
#  index_orders_on_status_and_created_at            (status,created_at)
#  index_orders_on_user_id                          (user_id)
#  index_orders_on_user_id_and_status               (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class OrderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
