# 顧客（04 R2タスク1。Column.md §8 jasmin_customers が正）。CTO決定（03§8-2・04 R2冒頭）どおり
# JasminCustomerプレフィックスを外しCustomerで実装する。
#
# T-3是正: contract_condition_id はここには持たせない（→ Order#contract_condition_id に一本化。
# db/migrate/20260815140014_create_customers.rb コメント参照）。
#
# customer_number の採番はSequenceCounter（PostgreSQLの単一UPSERT文でアトミック）で行う。
# Laravel現行の `static::count() + 1` は同時作成でcount()の読み取りタイミングがずれると
# 同じ番号を2件に払い出す（T-1系の脆弱性）。spec/models/customer_spec.rb で複数スレッドからの
# 同時作成でも重複しないことを検証する。
# == Schema Information
#
# Table name: customers
#
#  id                       :uuid             not null, primary key
#  address_detail           :string(200)
#  agency_customer_code     :string(50)
#  applicant_type           :string(20)
#  applied_at               :date
#  appointer_code           :string(20)
#  appointer_name           :string(50)
#  city                     :string(50)
#  confirm_staff_code       :string(20)
#  confirm_staff_name       :string(50)
#  consolidated_billing     :boolean
#  contact2_dept_phone      :string(20)
#  contact2_name            :string(100)
#  contact2_name_kana       :string(100)
#  contact2_title           :string(50)
#  contact_dept_phone       :string(20)
#  contact_name             :string(100)
#  contact_name_kana        :string(100)
#  contact_title            :string(50)
#  contracted_at            :date
#  contractor_name_kana     :string(255)
#  customer_number          :string(20)       not null
#  email                    :string(255)
#  encrypted_password       :string           default(""), not null
#  failed_attempts          :integer          default(0), not null
#  fax_number               :string(20)
#  industry                 :string(50)
#  industry_sub             :string(50)
#  inventory_type           :string(50)
#  invoice_address          :string(500)
#  invoice_destination      :string(50)
#  invoice_name             :string(255)
#  invoice_name_kana        :string(255)
#  invoice_other_phone      :string(20)
#  invoice_phone            :string(20)
#  invoice_postal_code      :string(8)
#  lbc_code                 :string(20)
#  locked_at                :datetime
#  mobile_contact_person    :string(50)
#  mobile_phone             :string(20)
#  name                     :string(255)      not null
#  netmove_registered_at    :date
#  num_employees            :integer
#  num_offices              :integer
#  otp_attempts             :integer          default(0), not null
#  otp_code_digest          :string
#  otp_code_expires_at      :datetime
#  phone                    :string(20)
#  postal_code              :string(8)
#  prefecture               :string(20)
#  representative_name      :string(100)
#  representative_name_kana :string(100)
#  sales_mgmt_customer_code :string(20)
#  sms_mobile_number        :string(20)
#  status                   :string(50)       default("applied"), not null
#  town                     :string(100)
#  unlock_token             :string
#  years_in_business        :string(20)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agency_id                :uuid             not null
#  created_by_id            :uuid
#  netmove_member_id        :string(50)
#  sales_representative_id  :uuid
#  updated_by_id            :uuid
#
# Indexes
#
#  index_customers_on_agency_id                (agency_id)
#  index_customers_on_applied_at               (applied_at)
#  index_customers_on_customer_number          (customer_number) UNIQUE
#  index_customers_on_email                    (email) UNIQUE
#  index_customers_on_name                     (name)
#  index_customers_on_sales_representative_id  (sales_representative_id)
#  index_customers_on_status                   (status)
#  index_customers_on_unlock_token             (unlock_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (sales_representative_id => sales_representatives.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
class Customer < ApplicationRecord
  # 04 R4タスク5・03§4「顧客マイページ(Customer)はDevise別スコープ」。db/migrate/20260815160012が
  # 追加した列に対応する。:validatable/:registerable/:recoverableは意図的に外す（migrationコメント
  # 参照）: R3の申込トランザクションがパスワード無しでCustomerを大量生成するため、Deviseの既定
  # バリデーション（email/password presence等）を持ち込むとその経路を壊す。マイページは
  # 「ログイン+ダッシュボードのみの最小構成」（04 R4本文）でパスワード再設定UIも対象外。
  # unlock_strategy: :time でロック解除もメール送信無し（過剰実装を避ける）。
  devise :database_authenticatable, :lockable, :timeoutable,
         unlock_strategy: :time, lock_strategy: :failed_attempts, maximum_attempts: 5

  # OtpAuthenticatable→AuthAuditableの順でincludeすること（User#の同順コメント参照。
  # AuthAuditable#after_otp_eventがsuper経由でOtpAuthenticatable側のフックを呼ぶ前提）。
  include OtpAuthenticatable
  include AuthAuditable
  include TracksUser
  include Auditable

  belongs_to :agency
  belongs_to :sales_representative, optional: true

  has_many :stores, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :system_notifications, as: :recipient, dependent: :destroy

  # customer_numberはpresenceバリデーション対象のため、before_create（バリデーション後）ではなく
  # before_validationで採番する（before_createにすると常に「空のまま」バリデーションに失敗する）。
  before_validation :assign_default_status, on: :create
  before_validation :assign_customer_number, on: :create

  validates :customer_number, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :status, presence: true, length: { maximum: 50 }
  validate :status_must_exist_in_customer_statuses

  validates :applicant_type, length: { maximum: 20 }
  validates :agency_customer_code, length: { maximum: 50 }
  validates :inventory_type, length: { maximum: 50 }
  validates :contractor_name_kana, length: { maximum: 255 }
  validates :representative_name, :contact_name, :contact2_name, length: { maximum: 100 }
  validates :representative_name_kana, :contact_name_kana, :contact2_name_kana, length: { maximum: 100 }
  validates :contact_title, :contact2_title, length: { maximum: 50 }
  validates :contact_dept_phone, :contact2_dept_phone, length: { maximum: 20 }
  validates :postal_code, :invoice_postal_code, length: { maximum: 8 }
  validates :prefecture, length: { maximum: 20 }
  validates :city, length: { maximum: 50 }
  validates :town, length: { maximum: 100 }
  validates :address_detail, length: { maximum: 200 }
  validates :phone, :fax_number, :mobile_phone, :invoice_phone, :invoice_other_phone, length: { maximum: 20 }
  validates :mobile_contact_person, length: { maximum: 50 }
  validates :email, length: { maximum: 255 }
  validates :industry, :industry_sub, length: { maximum: 50 }
  validates :years_in_business, length: { maximum: 20 }
  validates :num_employees, :num_offices, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :invoice_destination, length: { maximum: 50 }
  validates :invoice_name, :invoice_name_kana, length: { maximum: 255 }
  validates :invoice_address, length: { maximum: 500 }
  validates :confirm_staff_code, :appointer_code, :lbc_code, :sales_mgmt_customer_code, length: { maximum: 20 }
  validates :confirm_staff_name, :appointer_name, length: { maximum: 50 }
  validates :netmove_member_id, length: { maximum: 50 }
  validates :sms_mobile_number, length: { maximum: 20 }

  # 退会済みを除くスコープ（Laravel JasminCustomer#scopeActive踏襲）。
  scope :active, -> { where.not(status: CustomerStatus::CODE_WITHDRAWN) }

  # 退会済み顧客はマイページへログインできない（User#active_for_authentication?のCustomer版。
  # is_activeフラグを持たないCustomerでは、CustomerStatus::CODE_WITHDRAWNをその代替として使う）。
  def active_for_authentication?
    super && status != CustomerStatus::CODE_WITHDRAWN
  end

  # Devise/OTPの通知メールを非同期送信する（User#send_devise_notification踏襲。ただしCustomerは
  # :recoverable等を持たないためDeviseからの発火は実質lockable系の通知のみ）。
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  private

  def assign_default_status
    self.status = CustomerStatus::CODE_APPLIED if status.blank?
  end

  def assign_customer_number
    return if customer_number.present?

    self.customer_number = format("C-%06d", SequenceCounter.next_value!("customer_number"))
  end

  def status_must_exist_in_customer_statuses
    return if status.blank?
    return if CustomerStatus.exists?(code: status)

    errors.add(:status, "はcustomer_statusesに存在しないコードです（#{status}）")
  end
end
