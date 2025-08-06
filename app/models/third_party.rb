# == Schema Information
#
# Table name: third_parties
#
#  id           :bigint           not null, primary key
#  enabled      :boolean
#  name         :string
#  slug         :string
#  token        :text
#  token_expire :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class ThirdParty < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  
  scope :enabled, -> { where(enabled: true) }
  
  def token_expired?
    token_expire.nil? || token_expire < Time.current
  end
  
  def token_expires_soon?(minutes = 10)
    token_expire.nil? || token_expire < minutes.minutes.from_now
  end
end
