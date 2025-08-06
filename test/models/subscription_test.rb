# == Schema Information
#
# Table name: subscriptions
#
#  id                :bigint           not null, primary key
#  expires_at        :datetime
#  payment_reference :string
#  status            :integer          default("active"), not null
#  subscribed_at     :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_payment_reference  (payment_reference) UNIQUE
#  index_subscriptions_on_status             (status)
#  index_subscriptions_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "123456",
    )
    @subscription = Subscription.new(
      user: @user,
      payment_reference: "ABC123",
      expires_at: 2.days.from_now,
      subscribed_at: Time.current,
      status: :active,
    )
  end

  test "valid subscription" do
    assert @subscription.valid?
  end

  test "invalid without payment_reference" do
    @subscription.payment_reference = nil
    assert_not @subscription.valid?
  end

  test "active? returns true if not expired" do
    assert @subscription.active?
  end

  test "expired? returns false if not expired" do
    assert_not @subscription.expired?
  end

  test "days_until_expiry returns correct days" do
    assert_equal 2, @subscription.days_until_expiry
  end

  test "expires_soon? returns true if within 3 days" do
    assert @subscription.expires_soon?
  end
end
