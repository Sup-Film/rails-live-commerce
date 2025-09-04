# == Schema Information
#
# Table name: shipping_providers
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE)
#  code       :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_shipping_providers_on_code  (code) UNIQUE
#
class ShippingProvider < ApplicationRecord
  has_many :users, foreign_key: :default_shipping_provider_id
  scope :active, -> { where(active: true) }

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :active, inclusion: { in: [true, false] }
end
