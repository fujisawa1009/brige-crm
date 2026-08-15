# 案件（04 R2タスク1。Column.md §10 jasmin_orders が正。約90フィールド）。CTO決定どおり
# JasminOrderプレフィックスを外しOrderで実装する。
#
# T-3是正の反映（04 R1申し送り）: contract_condition_id はこのモデルで必須(FK, not null)にする
# （受注時点の契約条件バージョンを固定参照。是正前のLaravelはcustomers側に持っていた）。
#
# order_number の採番（ORD{年}{連番4桁}形式）はSequenceCounterで年ごとのキー
# （例: "order_number_2026"）を使いアトミックに払い出す。Laravel現行の
# `whereYear('created_at', $year)->count() + 1` は同時作成で重複しうる（T-1系の脆弱性の是正。
# spec/models/order_spec.rb で並行作成時の重複が起きないことを検証する）。
#
# PII暗号化（pii-handling-rules.md §1 分類B・請求パスワード）: billing_password は
# ActiveRecord::Encryption で暗号化保存する（config/credentials.yml.enc の
# active_record_encryption鍵設定必須。db:encryption:init で生成済み）。
# == Schema Information
#
# Table name: orders
#
#  id                             :uuid             not null, primary key
#  account_issued_at              :date
#  accounting_month               :string(6)
#  billing_password               :text
#  bridge_accounting_month        :string(6)
#  bridge_agency_name             :string(100)
#  bridge_migration               :string(5)
#  bridge_migration_order_number  :string(20)
#  bridge_sales_rep_name          :string(50)
#  bundle_target_order_number     :string(20)
#  bundled_billing                :string(5)
#  business_auth_doc              :string(5)
#  business_auth_doc_collected_at :date
#  business_proof                 :string(200)
#  cancelled_at                   :date
#  citation_applied               :string(5)
#  citation_count                 :integer
#  citation_existing_serial       :string(50)
#  citation_plan                  :string(50)
#  confirm_call_contact_name      :string(50)
#  confirm_call_notes             :text
#  confirm_call_preferred_date    :string(50)
#  confirm_call_remarks           :text
#  confirm_call_staff_name        :string(50)
#  confirm_call_time              :string(100)
#  consent_contact_age            :integer
#  consent_rep_age                :integer
#  consent_status                 :string(20)
#  contract_sent_at               :date
#  contract_start_date            :date
#  contract_status                :string(10)
#  domestic_citation_plan         :string(50)
#  elderly_consent                :string(5)
#  elderly_consent_collected_at   :date
#  external_link_applied          :string(5)
#  external_link_count            :integer
#  external_link_type             :string(20)
#  factor_notes                   :string(200)
#  finance_address_detail         :string(100)
#  finance_building               :string(100)
#  finance_city                   :string(50)
#  finance_division               :string(20)
#  finance_installer              :string(100)
#  finance_phone                  :string(20)
#  finance_postal_code            :string(8)
#  finance_prefecture             :string(20)
#  finance_town                   :string(100)
#  gbp_multilingual               :string(5)
#  google_ads_applied             :string(5)
#  google_ads_count               :integer
#  google_review_display          :string(5)
#  infobiz_applied                :string(5)
#  inspection_call_completed_at   :date
#  inspection_call_history        :text
#  inspection_call_ng_time        :string(100)
#  issued_at                      :date
#  language_selection             :string(100)
#  meo_existing_serial            :string(50)
#  meo_mgmt_number                :string(20)
#  meo_premium_applied            :string(5)
#  onerank_cms                    :string(5)
#  order_number                   :string(20)       not null
#  ordered_at                     :date
#  owlet_cms                      :string(5)
#  paper_address_note             :string(200)
#  payment_collected_at           :date
#  payment_doc_confirmed_at       :date
#  payment_method                 :string(50)
#  plus_applied                   :string(5)
#  portal_site_applied            :string(5)
#  remarks                        :text
#  reservation_system             :string(50)
#  review_heading                 :string(100)
#  s_plan_cms                     :string(5)
#  sales_mgmt_slip_number         :string(20)
#  shared_notes                   :text
#  status                         :string(50)       default("0:受注"), not null
#  terminated_at                  :date
#  termination_reason             :string(200)
#  toss_up_code                   :string(20)
#  work_completed_at              :date
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  agency_id                      :uuid             not null
#  contract_condition_id          :uuid             not null
#  created_by_id                  :uuid
#  customer_id                    :uuid             not null
#  member_id                      :string(20)
#  plan_id                        :uuid
#  product_initial_fee_id         :uuid
#  sales_representative_id        :uuid
#  serial_id                      :string(20)
#  store_id                       :uuid
#  updated_by_id                  :uuid
#
# Indexes
#
#  index_orders_on_agency_id                (agency_id)
#  index_orders_on_contract_condition_id    (contract_condition_id)
#  index_orders_on_customer_id              (customer_id)
#  index_orders_on_order_number             (order_number) UNIQUE
#  index_orders_on_plan_id                  (plan_id)
#  index_orders_on_product_initial_fee_id   (product_initial_fee_id)
#  index_orders_on_sales_representative_id  (sales_representative_id)
#  index_orders_on_status                   (status)
#  index_orders_on_store_id                 (store_id)
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (contract_condition_id => contract_conditions.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (customer_id => customers.id) ON DELETE => restrict
#  fk_rails_...  (plan_id => plans.id) ON DELETE => nullify
#  fk_rails_...  (product_initial_fee_id => product_initial_fees.id) ON DELETE => nullify
#  fk_rails_...  (sales_representative_id => sales_representatives.id) ON DELETE => nullify
#  fk_rails_...  (store_id => stores.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
class Order < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :customer
  belongs_to :store, optional: true
  belongs_to :sales_representative, optional: true
  belongs_to :agency
  belongs_to :contract_condition
  belongs_to :plan, optional: true
  belongs_to :product_initial_fee, optional: true

  has_one :order_work_detail, dependent: :destroy

  # 04 R3: 選択オプション（jasmin_order_options相当。04 R2の申し送りをここで解消）。
  # product_option_ids= はForm::ApplicationSubmissionServiceがFormField(target_table: "order",
  # target_column: "product_option_ids")経由で呼ぶ、has_many :through が自動生成する集合idsライター。
  has_many :order_options, dependent: :destroy
  has_many :product_options, through: :order_options
  has_many :applications, dependent: :nullify

  encrypts :billing_password

  # order_numberはpresenceバリデーション対象のため、Customer同様にbefore_validationで採番する。
  before_validation :assign_default_status, on: :create
  before_validation :assign_order_number, on: :create

  validates :order_number, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :status, presence: true, length: { maximum: 50 }
  validate :status_must_exist_in_order_statuses

  validates :serial_id, length: { maximum: 20 }
  validates :payment_method, length: { maximum: 50 }
  validates :plus_applied, length: { maximum: 5 }
  validates :contract_status, length: { maximum: 10 }
  validates :accounting_month, :bridge_accounting_month, length: { maximum: 6 }
  validates :termination_reason, length: { maximum: 200 }
  validates :consent_rep_age, :consent_contact_age,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :citation_count, :external_link_count, :google_ads_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_year, ->(year) { where("EXTRACT(YEAR FROM created_at) = ?", year) }

  private

  def assign_default_status
    self.status = OrderStatus::CODE_ORDERED if status.blank?
  end

  def assign_order_number
    return if order_number.present?

    year = Time.current.strftime("%Y")
    seq  = SequenceCounter.next_value!("order_number_#{year}")
    self.order_number = format("ORD%s%04d", year, seq)
  end

  def status_must_exist_in_order_statuses
    return if status.blank?
    return if OrderStatus.exists?(code: status)

    errors.add(:status, "はorder_statusesに存在しないコードです（#{status}）")
  end
end
