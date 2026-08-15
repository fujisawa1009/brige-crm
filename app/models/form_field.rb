# P2拡張後仕様のフィールド定義そのもの（04 R3タスク3。development-plan.mdのtarget_table/
# target_column/editable_by_tier/lock_after_statusを初期スキーマから採用）。
#
# target_table/target_column: 回答の書き込み先（Form::ApplicationSubmissionServiceが
# `record.public_send("#{target_column}=", value)` で反映する）。target_columnは通常のカラムに
# 限らず、has_many :through が生成する集合idsライター（例: Order#product_option_ids=）も指せる。
# これにより「選択オプション（jasmin_order_options相当のOrder⇄ProductOption中間テーブル）」も
# target_table特別扱いなしで同じ仕組みに乗る（申込フォームの動的マッピングの核）。
#
# input_options/validation_rules はjsonbだが、管理画面フォームでは生JSONを直接編集させず
# input_options_json/validation_rules_json という仮想属性（テキストエリア）経由でパースする
# （任意ネストハッシュをstrong parametersでpermitする設計より安全・単純。04 R3タスク6）。
# == Schema Information
#
# Table name: form_fields
#
#  id                :uuid             not null, primary key
#  editable_by_tier  :string           default(["sales_representative"]), not null, is an Array
#  field_key         :string           not null
#  field_type        :string           not null
#  input_options     :jsonb            not null
#  label             :string           not null
#  lock_after_status :string
#  required          :boolean          default(FALSE), not null
#  sort_order        :integer          default(0), not null
#  target_column     :string
#  target_table      :string           not null
#  validation_rules  :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  created_by_id     :uuid
#  form_step_id      :uuid             not null
#  updated_by_id     :uuid
#
# Indexes
#
#  index_form_fields_on_editable_by_tier            (editable_by_tier) USING gin
#  index_form_fields_on_form_step_id_and_field_key  (form_step_id,field_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (form_step_id => form_steps.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class FormField < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :form_step

  FIELD_TYPES = %w[text textarea date integer boolean select checkbox_group].freeze
  TARGET_TABLES = %w[customer store order order_work_detail].freeze
  # 3次元編集権限のうち「誰が」の次元（04 R3タスク3）。R3で実際にフォームを操作するのは
  # sales_representativeのみだが、R4/R5で代理店・管理者による再編集を追加する余地を残す。
  TIERS = %w[sales_representative agency admin].freeze
  TIER_SALES_REPRESENTATIVE = "sales_representative"

  attr_accessor :input_options_json, :validation_rules_json

  before_validation :parse_json_virtual_attributes
  before_validation :normalize_editable_by_tier

  validates :field_key, presence: true, length: { maximum: 100 },
            uniqueness: { scope: :form_step_id },
            format: { with: /\A[a-z][a-z0-9_]*\z/, message: "は英小文字・数字・アンダースコアのみ使用できます" }
  validates :label, presence: true, length: { maximum: 255 }
  validates :field_type, presence: true, inclusion: { in: FIELD_TYPES }
  validates :target_table, presence: true, inclusion: { in: TARGET_TABLES }
  validates :target_column, presence: true, length: { maximum: 100 }
  validates :editable_by_tier, presence: true
  validate :editable_by_tier_must_be_known_tiers
  validate :lock_after_status_must_exist_in_order_statuses

  scope :ordered, -> { order(:sort_order) }
  # 指定tierが編集可能なフィールドのみに絞る（Postgres配列の包含検索）。
  # Form::DynamicFormValidator・Form::ApplicationsController#show_stepの両方が使う。
  scope :editable_by, ->(tier) { where("? = ANY (editable_by_tier)", tier) }

  # R4/R5の再編集フロー向け（04 R3タスク3のlock_after_status活用先）。R3の新規申込トランザクションは
  # 同一トランザクション内でOrderを新規作成するため呼ばれないが、データとロジックをここで用意しておく。
  def locked_for?(order)
    return false if lock_after_status.blank? || order.blank?

    threshold = OrderStatus.find_by(code: lock_after_status)
    current   = OrderStatus.find_by(code: order.status)
    return false if threshold.blank? || current.blank?

    current.sort_order >= threshold.sort_order
  end

  private

  def parse_json_virtual_attributes
    self.input_options    = parse_json(input_options_json, :input_options_json)    if input_options_json.present?
    self.validation_rules = parse_json(validation_rules_json, :validation_rules_json) if validation_rules_json.present?
  end

  def parse_json(text, attribute)
    JSON.parse(text)
  rescue JSON::ParserError
    errors.add(attribute, "はJSON形式で入力してください")
    {}
  end

  # チェックボックス群からの送信はStringの配列で届くため、空文字列（未選択時の隠しフィールド）を除去する。
  def normalize_editable_by_tier
    self.editable_by_tier = Array(editable_by_tier).reject(&:blank?) if editable_by_tier.present?
  end

  def editable_by_tier_must_be_known_tiers
    unknown = Array(editable_by_tier) - TIERS
    return if unknown.empty?

    errors.add(:editable_by_tier, "に未知の区分が含まれています（#{unknown.join(', ')}）")
  end

  def lock_after_status_must_exist_in_order_statuses
    return if lock_after_status.blank?
    return if OrderStatus.exists?(code: lock_after_status)

    errors.add(:lock_after_status, "はorder_statusesに存在しないコードです（#{lock_after_status}）")
  end
end
