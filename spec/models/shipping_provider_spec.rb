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
require 'rails_helper'

RSpec.describe ShippingProvider, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
