# == Schema Information
#
# Table name: orders
#
#  id                        :bigint           not null, primary key
#  checkout_completed_at     :datetime
#  checkout_token            :string           not null
#  checkout_token_expires_at :datetime
#  comment_time              :datetime
#  customer_address          :text
#  customer_email            :string
#  customer_name             :string
#  customer_phone            :string
#  deleted_at                :datetime
#  facebook_user_name        :string
#  order_number              :string           not null
#  paid_at                   :datetime
#  quantity                  :integer          default(1)
#  ref                       :string
#  status                    :integer          default("pending")
#  total_amount              :decimal(10, 2)
#  tracking                  :string
#  unit_price                :decimal(10, 2)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  facebook_comment_id       :string           not null
#  facebook_live_id          :string
#  facebook_user_id          :string           not null
#  product_id                :bigint           not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_orders_on_checkout_token                   (checkout_token) UNIQUE
#  index_orders_on_checkout_token_expires_at        (checkout_token_expires_at)
#  index_orders_on_comment_and_users                (facebook_comment_id,facebook_user_id,user_id) UNIQUE
#  index_orders_on_deleted_at                       (deleted_at)
#  index_orders_on_facebook_user_id_and_created_at  (facebook_user_id,created_at)
#  index_orders_on_order_number                     (order_number)
#  index_orders_on_product_id                       (product_id)
#  index_orders_on_user_id                          (user_id)
#  index_orders_on_user_id_and_status               (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#  fk_rails_...  (user_id => users.id)
#
class Order < ApplicationRecord
  # Scope สำหรับเช็คซ้ำ order ที่ยังไม่ถูกลบและยังอยู่ในสถานะที่ถือว่ายัง active
  scope :active_for_duplicate_check, -> { where(deleted_at: nil, status: [Order.statuses[:pending], Order.statuses[:paid]]) }
  belongs_to :product
  belongs_to :user

  validates :order_number, presence: true
  validates :facebook_comment_id, presence: true
  validates :checkout_token, presence: true, uniqueness: true
  validates :unit_price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { greater_than: 0 }

  enum status: {
    pending: 0,
    paid: 1,
    confirmed: 2,
    cancelled: 3,
    refunded: 4,
    deleted: 5,
  }

  before_validation :generate_checkout_token, on: :create # สร้าง checkout token อัตโนมัติ
  before_save :set_unit_price_from_product

  # Scopes สำหรับ query orders ที่ไม่ถูกลบ
  scope :active, -> { where.not(status: ["cancelled", "deleted"]) }
  scope :not_deleted, -> { where.not(status: "deleted") }
  scope :cancellable, -> { where(status: ["pending", "paid"]) }

  def checkout_url
    # สำหรับ development ใช้ localhost, production ควรกำหนดใน config
    base_url = Rails.env.production? ? "https://5ed07b758d8c.ngrok-free.app" : "http://localhost:3000"
    "#{base_url}/checkout/#{checkout_token}"
  end

  def checkout_expired?
    checkout_token_expires_at.present? && checkout_token_expires_at < Time.current
  end

  def self.cleanup_expired_orders
    # ลบ orders ที่หมดอายุ
    expired_orders = where("checkout_token_expires_at < ?", Time.current)
    expired_orders.delete_all
  end

  # Methods สำหรับการยกเลิก/ลบ Order อย่างปลอดภัย
  def cancellable?
    status == "pending"
  end

  def soft_delete!
    # ลบแบบ soft delete โดยเปลี่ยน status
    begin
      update!(status: "deleted", deleted_at: Time.current)
    rescue FrozenError, ActiveRecord::RecordInvalid => e
      # ถ้า update ไม่ได้ใช้ raw SQL
      self.class.where(id: id).update_all(status: Order.statuses["deleted"], deleted_at: Time.current)
    end
  end

  private

  def generate_checkout_token
    self.checkout_token = SecureRandom.urlsafe_base64(32) if checkout_token.blank?
    self.checkout_token_expires_at = 24.hours.from_now if checkout_token_expires_at.blank?
  end

  def set_unit_price_from_product
    if product.present? && unit_price.blank?
      self.unit_price = product.productPrice
    end
  end
end
