# == Schema Information
#
# Table name: subscriptions
#
#  id               :bigint           not null, primary key
#  expires_at       :datetime
#  rejection_reason :text
#  status           :integer          default("pending_approval"), not null
#  subscribed_at    :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_status   (status)
#  index_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Subscription < ApplicationRecord
  belongs_to :user

  has_one_attached :payment_slip

  # Enums
  enum status: { active: 1, expired: 2 }

  # Validations
  validates :user_id, uniqueness: true
  validates :status, presence: true

  private

  # เช็คว่าไฟล์แนบ payment_slip มีอยู่หรือไม่
  def payment_slip_attached?
    # คืนค่า true ถ้ามีการแนบไฟล์ payment_slip
    payment_slip.attached?
  end
end
