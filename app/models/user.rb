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

  validates :provider, :uid, presence: true, if: :omniauth_login?

  def omniauth_login?
    provider.present? && uid.present?
  end

  def self.from_omniauth(auth)
    # กรณีเคย Login ด้วย Facebook แล้ว
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    if user
      user.update(
        oauth_token: auth.credentials.token,
        oauth_expires_at: auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil,
      )
    end

    # ไม่เคย Login ด้วย Facebook แต่มีอีเมลอยู่ในระบบ
    user = User.find_by(email: auth.info.email)
    if user
      user.update(
        provider: auth.provider,
        uid: auth.uid,
        image: auth.info.image,
        oauth_token: auth.credentials.token,
        oauth_expires_at: auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil,
      )
      return user
    end

    # ไม่เคย Login ด้วย Facebook และไม่เคยสมัครสมาชิกจากระบบ
    User.create do |new_user|
      new_user.provider = auth.provider
      new_user.uid = auth.uid
      new_user.name = auth.info.name
      new_user.email = auth.info.email
      new_user.image = auth.info.image
      new_user.oauth_token = auth.credentials.token
      new_user.oauth_expires_at = auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil
    end

    # where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
    #   user.provider = auth.provider
    #   user.uid = auth.uid
    #   user.name = auth.info.name
    #   user.email = auth.info.email
    #   user.image = auth.info.image
    #   user.oauth_token = auth.credentials.token
    #   user.oauth_expires_at = auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil
    #   user.save!
    # end
  end
end
