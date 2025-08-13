# == Schema Information
#
# Table name: users
#
#  id               :bigint           not null, primary key
#  email            :string           not null
#  image            :string
#  name             :string
#  oauth_expires_at :datetime
#  oauth_token      :string
#  password_digest  :string
#  provider         :string
#  role             :integer          default("user"), not null
#  uid              :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  has_secure_password

  # Enums
  enum role: { user: 0, admin: 1 }

  # Relations
  has_many :products, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  # Subscription methods
  def current_subscription
    subscriptions.active.first
  end

  def subscribed?
    current_subscription&.active? || false
  end

  def subscription_expired?
    !subscribed?
  end

  def subscription_expires_soon?(days = 3)
    current_subscription&.expires_soon?(days) || false
  end

  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
end
