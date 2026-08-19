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
#  contract_status                :string(50)
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
  has_many :contract_reviews, dependent: :restrict_with_error
  has_many :disclosure_checks, dependent: :restrict_with_error

  # 【2026-08-19 CEO決定（Q-45）: 暗号化を廃止し平文保存に変更】
  # 従来は encrypts :billing_password を適用していたが、「暗号化列を全部平文にする」というCEO決定に
  # 伴い除去した（決定の経緯・代替防御は app/models/order_work_detail.rb 冒頭のコメント参照）。
  # billing_password は口座振替の請求パスワードで pii-handling-rules.md 分類B相当。

  # order_numberはpresenceバリデーション対象のため、Customer同様にbefore_validationで採番する。
  before_validation :assign_default_status, on: :create
  before_validation :assign_order_number, on: :create

  validates :order_number, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :status, presence: true, length: { maximum: 50 }
  validate :status_must_exist_in_order_statuses

  validates :serial_id, length: { maximum: 20 }
  validate :payment_method_must_exist_in_payment_methods
  validates :plus_applied, length: { maximum: 5 }
  validates :contract_status, length: { maximum: 50 }
  validate :contract_status_must_exist_in_contract_statuses
  validates :accounting_month, :bridge_accounting_month, length: { maximum: 6 }
  validates :termination_reason, length: { maximum: 200 }
  validates :consent_rep_age, :consent_contact_age,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :citation_count, :external_link_count, :google_ads_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_year, ->(year) { where("EXTRACT(YEAR FROM created_at) = ?", year) }

  # 契約ワークフロー状態機械（04 R5-1・basic-design.md §9〜§12）。
  # キーは [遷移前のcontract_status（未着手はnil）, event]、値は遷移後のcontract_status。
  # 遷移図の確定根拠は basic-design.md の記述（「問題がなければ次工程へ、問題があれば差戻し」
  # 「差戻し後は代理店営業担当者または顧客が修正可能とし、修正後は再度チェック待ちに戻す」
  # 「確認コール後、結果に応じて契約確定または再差戻しの判断を行う」）を1本の状態機械へ具体化した
  # 初版であり、差戻し中/再申請待ちの区切り方など細部は業務レビュー未実施（要確認）。
  # 変更する場合は必ずこの定数とspec/models/order_spec.rbの遷移表specを同時に更新すること。
  CONTRACT_STATUS_TRANSITIONS = {
    [ nil, "check_requested" ] => ContractStatus::CODE_PENDING_CHECK,

    [ ContractStatus::CODE_PENDING_CHECK, "check_passed" ]   => ContractStatus::CODE_CONFIRM_CALL_PENDING,
    [ ContractStatus::CODE_PENDING_CHECK, "check_returned" ] => ContractStatus::CODE_RETURNED,

    [ ContractStatus::CODE_RETURNED, "start_correction" ] => ContractStatus::CODE_BEING_CORRECTED,

    [ ContractStatus::CODE_BEING_CORRECTED, "await_reapplication" ] => ContractStatus::CODE_REAPPLICATION_PENDING,

    [ ContractStatus::CODE_REAPPLICATION_PENDING, "resubmitted" ] => ContractStatus::CODE_RECHECK_PENDING,

    [ ContractStatus::CODE_RECHECK_PENDING, "check_passed" ]   => ContractStatus::CODE_CONFIRM_CALL_PENDING,
    [ ContractStatus::CODE_RECHECK_PENDING, "check_returned" ] => ContractStatus::CODE_RETURNED,

    [ ContractStatus::CODE_CONFIRM_CALL_PENDING, "call_done" ]        => ContractStatus::CODE_CONFIRM_CALL_DONE,
    [ ContractStatus::CODE_CONFIRM_CALL_PENDING, "call_inconclusive" ] => ContractStatus::CODE_NEEDS_RECONFIRMATION,
    [ ContractStatus::CODE_CONFIRM_CALL_PENDING, "call_returned" ]    => ContractStatus::CODE_RETURNED,

    [ ContractStatus::CODE_NEEDS_RECONFIRMATION, "call_pending_again" ] => ContractStatus::CODE_CONFIRM_CALL_PENDING,

    [ ContractStatus::CODE_CONFIRM_CALL_DONE, "confirm" ]       => ContractStatus::CODE_CONTRACT_CONFIRMATION_PENDING,
    [ ContractStatus::CODE_CONFIRM_CALL_DONE, "call_returned" ] => ContractStatus::CODE_RETURNED,

    [ ContractStatus::CODE_CONTRACT_CONFIRMATION_PENDING, "contract_confirmed" ] => ContractStatus::CODE_CONTRACTED,
    [ ContractStatus::CODE_CONTRACT_CONFIRMATION_PENDING, "call_returned" ]      => ContractStatus::CODE_RETURNED
  }.freeze

  InvalidContractTransition = Class.new(StandardError)

  # 不正遷移は例外にする（payment-integration.md §4-4のPaymentTransaction状態機械と同じ方針）。
  # with_lockで行ロックを取り、同一Orderへの同時遷移操作（管理者が2画面から同時操作等）を防ぐ。
  def transition_contract_to!(event, reason: nil, target_fields: nil, comment: nil, returned_to: nil, performed_by: nil)
    with_lock do
      from_status = contract_status
      to_status = self.class::CONTRACT_STATUS_TRANSITIONS[[ from_status, event ]]

      if to_status.nil?
        raise InvalidContractTransition, "#{from_status.inspect}からevent=#{event}への遷移は許可されていません"
      end

      update!(contract_status: to_status)
      contract_reviews.create!(
        event: event,
        from_status: from_status,
        to_status: to_status,
        reason: reason,
        target_fields: target_fields || {},
        comment: comment,
        returned_to: returned_to,
        performed_by: performed_by,
        performed_at: Time.current
      )
    end
  end

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

  def payment_method_must_exist_in_payment_methods
    return if payment_method.blank?
    return if PaymentMethod.exists?(code: payment_method)

    errors.add(:payment_method, "はpayment_methodsに存在しないコードです（#{payment_method}）")
  end

  def contract_status_must_exist_in_contract_statuses
    return if contract_status.blank?
    return if ContractStatus.exists?(code: contract_status)

    errors.add(:contract_status, "はcontract_statusesに存在しないコードです（#{contract_status}）")
  end
end
