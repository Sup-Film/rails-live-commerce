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
#  facebook_user_name        :string
#  order_number              :string           not null
#  paid_at                   :datetime
#  quantity                  :integer          default(1)
#  status                    :integer          default("pending")
#  total_amount              :decimal(10, 2)
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
  belongs_to :product
  belongs_to :user

  validates :order_number, presence: true
  validates :facebook_comment_id, presence: true

  # ป้องกันการสร้าง order ซ้ำจาก comment เดียวกันของ user เดียวกัน
  validates :facebook_comment_id, uniqueness: { scope: [:facebook_user_id, :user_id],
                                        message: "This comment has already been processed for this user" }
  validates :checkout_token, presence: true, uniqueness: true
  validates :unit_price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { greater_than: 0 }

  enum status: {
    pending: 0,
    paid: 1,
    confirmed: 2,
    cancelled: 3,
    refunded: 4,
    deleted: 5
  }

  before_validation :generate_checkout_token, on: :create # สร้าง checkout token อัตโนมัติ
  before_validation :set_unit_price_from_product # ตั้งค่า unit_price จาก product
  before_validation :calculate_total_amount # คำนวณ total_amount ก่อน validation

  # Scopes สำหรับ query orders ที่ไม่ถูกลบ
  scope :active, -> { where.not(status: ['cancelled', 'deleted']) }
  scope :not_deleted, -> { where.not(status: 'deleted') }
  scope :cancellable, -> { where(status: ['pending', 'paid']) }

  def checkout_url
    # สำหรับ development ใช้ localhost, production ควรกำหนดใน config
    base_url = Rails.env.production? ? "https://your-domain.com" : "http://localhost:3000"
    "#{base_url}/checkout/#{checkout_token}"
  end

  def checkout_expired?
    checkout_token_expires_at.present? && checkout_token_expires_at < Time.current
  end

  # ช่วยในการ debug และ force delete
  def force_delete!
    # ลบโดยข้าม validations และ callbacks
    delete
  end

  def force_destroy!
    # ลบโดยข้าม frozen check และ validations
    self.class.where(id: id).delete_all
  end

  def safe_destroy
    # ลองลบแบบปกติก่อน ถ้าไม่ได้ใช้ force
    begin
      destroy
    rescue FrozenError, ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Normal destroy failed: #{e.message}, using force delete"
      force_delete!
    end
  end

  def can_be_deleted?
    # ตรวจสอบว่าสามารถลบได้หรือไม่
    errors.clear

    # ตรวจสอบ associations ที่อาจป้องกันการลบ
    begin
      valid?
      return true
    rescue => e
      Rails.logger.error "Cannot delete order #{id}: #{e.message}"
      return false
    end
  end

  # เพิ่ม debug logging ถ้าต้องการ
  def debug_frozen_state
    Rails.logger.debug "Order #{id} frozen state: #{frozen?}" if Rails.env.development?
  end

  # Class methods สำหรับลบ
  def self.force_delete_all
    # ลบทั้งหมดโดยข้าม callbacks
    delete_all
  end

  def self.safe_delete_by_ids(ids)
    # ลบตาม IDs โดยข้าม frozen check
    where(id: ids).delete_all
  end

  def self.cleanup_expired_orders
    # ลบ orders ที่หมดอายุ
    expired_orders = where("checkout_token_expires_at < ?", Time.current)
    expired_orders.delete_all
  end

  # Methods สำหรับการยกเลิก/ลบ Order อย่างปลอดภัย
  def cancel_order!
    # ยกเลิก order โดยเปลี่ยน status แทนการลบ
    begin
      update!(status: 'cancelled')
    rescue FrozenError, ActiveRecord::RecordInvalid => e
      # ถ้า update ไม่ได้ใช้ raw SQL
      self.class.where(id: id).update_all(status: Order.statuses['cancelled'])
    end
  end

  def soft_delete!
    # ลบแบบ soft delete โดยเปลี่ยน status
    begin
      update!(status: 'deleted')
    rescue FrozenError, ActiveRecord::RecordInvalid => e
      # ถ้า update ไม่ได้ใช้ raw SQL
      self.class.where(id: id).update_all(status: Order.statuses['deleted'])
    end
  end

  def hard_delete!
    # ลบจริงๆ โดยข้าม frozen check
    begin
      destroy!
    rescue FrozenError => e
      # ใช้ raw SQL ลบโดยตรง
      self.class.where(id: id).delete_all
    end
  end

  def safe_remove
    # ลบอย่างปลอดภัย - ลองทุกวิธี
    return cancel_order! if pending? || paid?  # ยกเลิกถ้ายังไม่ส่งของ
    return soft_delete!  # หรือ soft delete
  end

  private

  def generate_checkout_token
    return if frozen? # ป้องกันการแก้ไข frozen object
    self.checkout_token = SecureRandom.urlsafe_base64(32) if checkout_token.blank?
    self.checkout_token_expires_at = 24.hours.from_now if checkout_token_expires_at.blank?
  end

  def calculate_total_amount
    return if frozen? # ป้องกันการแก้ไข frozen object
    return if total_amount.present? # ไม่คำนวณใหม่ถ้ามีค่าแล้ว

    if unit_price.present? && quantity.present?
      self.total_amount = unit_price * quantity
    end
  end

  def set_unit_price_from_product
    return if frozen? # ป้องกันการแก้ไข frozen object
    return if unit_price.present? # ไม่เซ็ตใหม่ถ้ามีค่าแล้ว

    if product.present?
      self.unit_price = product.productPrice
    end
  end
end
