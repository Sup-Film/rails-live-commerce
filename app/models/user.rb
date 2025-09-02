# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  bank_account_name      :string
#  bank_account_number    :string
#  bank_code              :string
#  email                  :string           not null
#  image                  :string
#  name                   :string
#  oauth_expires_at       :datetime
#  oauth_token            :string
#  password_digest        :string
#  provider               :string
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("user"), not null
#  uid                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  has_secure_password

  # Enums
  enum role: { user: 0, admin: 1 }
  BANK_CODES = {
    "BBL"   => "002", # ธนาคารกรุงเทพ
    "KBANK" => "004", # ธนาคารกสิกรไทย
    "KTB"   => "006", # ธนาคารกรุงไทย
    "TTB"   => "011", # ธนาคารทหารไทยธนชาต
    "SCB"   => "014", # ธนาคารไทยพาณิชย์
    "UOB"   => "025", # ธนาคารยูโอบี
    "BAY"   => "022", # ธนาคารกรุงศรีอยุธยา
    "GSB"   => "030", # ธนาคารออมสิน
    "BAAC"  => "034", # ธ.ก.ส.
    "CITI"  => "069", # ธนาคารซิตี้แบงก์
    "CIMB"  => "067", # ธนาคาร CIMB ไทย
    "KKP"   => "070", # ธนาคารเกียรตินาคินภัทร
  }.freeze

  # Relations
  has_many :products, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :credit_ledgers, -> { order(created_at: :asc) }

  # Bank code
  def bank_name
    BANK_CODES.key(self.bank_code)
  end

  # Subscription methods
  def current_subscription
    subscriptions.active.first
  end

  def subscribed?
    current_subscription&.active? || false
  end

  def subscription_expired?
    !subscribed?
  end

  def subscription_expires_soon?(days = 3)
    current_subscription&.expires_soon?(days) || false
  end

  # Credit Ledger methods

  # ดึงยอดล่าสุด (หน่วยเป็น cents)
  def credit_balance_cents
    credit_ledgers.last&.balance_after_cents || 0
  end

  # แปลงจาก cents เป็นบาท
  def credit_balance
    credit_balance_cents / 100.0
  end

  # ตรวจสอบว่ามีเครดิตเพียงพอไหม จากจำนวนที่ต้องการ (หน่วยเป็น cents)
  def has_sufficient_credit?(amount_in_cents)
    credit_balance_cents >= amount_in_cents
  end

  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :bank_account_number, presence: true, length: { in: 10..12 }, numericality: { only_integer: true }, allow_blank: true
  validates :bank_account_name, presence: true, allow_blank: true
  validates :bank_code, inclusion: { in: BANK_CODES.values }, allow_blank: true

  # Password Reset Methods
  def generate_password_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64(32)
    self.reset_password_sent_at = Time.current
    save!(validate: false)
  end

  def password_reset_token_expired?
    reset_password_sent_at < 2.hours.ago
  end

  def reset_password!(new_password)
    self.password = new_password
    self.reset_password_token = nil
    self.reset_password_sent_at = nil
    save!
  end

  def self.find_by_password_reset_token(token)
    where(reset_password_token: token).where('reset_password_sent_at > ?', 2.hours.ago).first
  end
end
