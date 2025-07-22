# == Schema Information
#
# Table name: users
#
#  id               :bigint           not null, primary key
#  provider         :string
#  uid              :string
#  name             :string
#  email            :string
#  image            :string
#  oauth_token      :string
#  oauth_expires_at :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class User < ApplicationRecord
  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  has_many :products, dependent: :destroy
  has_many :orders, dependent: :destroy

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name
      user.email = auth.info.email
      user.image = auth.info.image
      user.oauth_token = auth.credentials.token
      user.oauth_expires_at = auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil
      user.save!
    end
  end
end
