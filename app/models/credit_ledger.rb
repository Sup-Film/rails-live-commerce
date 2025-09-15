# == Schema Information
#
# Table name: credit_ledgers
#
#  id                  :bigint           not null, primary key
#  amount_cents        :integer          default(0), not null
#  balance_after_cents :integer          not null
#  entry_type          :string           not null
#  idempotency_key     :string           not null
#  notes               :text
#  reference_type      :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  reference_id        :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_credit_ledgers_on_entry_type              (entry_type)
#  index_credit_ledgers_on_idempotency_key         (idempotency_key) UNIQUE
#  index_credit_ledgers_on_reference               (reference_type,reference_id)
#  index_credit_ledgers_on_user_id                 (user_id)
#  index_credit_ledgers_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class CreditLedger < ApplicationRecord
  # Relations
  belongs_to :user
  belongs_to :reference, polymorphic: true, optional: true

  # Validations
  validates :entry_type, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true }
  validates :balance_after_cents, presence: true, numericality: { only_integer: true }
  validates :idempotency_key, presence: true, uniqueness: true

  # Enum สำหรับประเภทรายการ
  enum entry_type: {
    top_up: "top_up",   # เติมเครดิต
    debit: "debit",     # หักเครดิต (เช่น ค่าขนส่ง)
    adjust: "adjust",    # ปรับปรุงโดย Admin
  }
end
