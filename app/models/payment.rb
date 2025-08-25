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
class Payment < ApplicationRecord
  # Attach Active Storage for the slip image
  has_one_attached :slip

  # Associations
  belongs_to :payable, polymorphic: true
  belongs_to :verified_by, class_name: 'User', optional: true

  # Validations
  validates :status, presence: true
  validates :slip, attached: true, on: :create # ต้องแนบสลิปตอนสร้างเสมอ

  # Scopes
  scope :pending, -> { where(status: 'pending') }
end
