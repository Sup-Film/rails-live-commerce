# == Schema Information
#
# Table name: payments
#
#  id             :bigint           not null, primary key
#  amount_cents   :integer          default(0), not null
#  external_ref   :string
#  metadata       :jsonb
#  payable_type   :string           not null
#  status         :string           default("pending"), not null
#  verified_at    :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  payable_id     :bigint           not null
#  verified_by_id :bigint
#
# Indexes
#
#  index_payments_on_external_ref                 (external_ref) UNIQUE
#  index_payments_on_payable_type_and_payable_id  (payable_type,payable_id)
#  index_payments_on_verified_by_id               (verified_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (verified_by_id => users.id)
#
require 'rails_helper'

RSpec.describe Payment, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
