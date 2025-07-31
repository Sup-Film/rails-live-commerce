# == Schema Information
#
# Table name: subscriptions
#
#  id               :bigint           not null, primary key
#  expires_at       :datetime
#  rejection_reason :text
#  status           :integer          default("pending_approval"), not null
#  subscribed_at    :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_status   (status)
#  index_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
