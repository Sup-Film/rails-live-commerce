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
class Subscription < ApplicationRecord
  belongs_to :user

  # Enums
  enum status: { active: 0, expired: 1 }

  # Validations
  validates :user_id, uniqueness: true
  validates :payment_reference, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :subscribed_at, presence: true
  validates :status, presence: true

  # Scopes
  scope :active_subscriptions, -> { where(status: :active).where("expires_at > ?", Time.current) }
  scope :expired_subscriptions, -> { where(status: :expired).or(where("expires_at <= ?", Time.current)) }

  # Methods
  def active?
    super && expires_at.present? && expires_at > Time.current
  end

  def expired?
    super || (expires_at && expires_at <= Time.current)
  end

  def days_until_expiry
    return 0 if expired?
    ((expires_at - Time.current) / 1.day).ceil
  end

  def expires_soon?(days = 3)
    active? && days_until_expiry <= days
  end

  # Auto-update expired subscriptions
  def self.update_expired_subscriptions
    where(status: :active)
      .where("expires_at <= ?", Time.current)
      .update_all(status: :expired)
  end
end
