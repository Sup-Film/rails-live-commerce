# == Schema Information
#
# Table name: subscriptions
#
#  id            :bigint           not null, primary key
#  expires_at    :datetime
#  status        :integer          default(0), not null
#  subscribed_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
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
class Subscription < ApplicationRecord
  belongs_to :user

  enum status: { pending_approval: 0, active: 1, expired: 2 }

  # Validations
  validates :user_id, uniqueness: true
  validates :status, presence: true
end
