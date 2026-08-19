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

  # target_table => 対応モデル（Form::ApplicationSubmissionServiceの既存マッピングと一致させる）。
  # R3レビュー指摘: target_columnホワイトリスト検証（#target_column_must_be_allowed）で使う。
  TARGET_MODELS = {
    "customer" => Customer,
    "store" => Store,
    "order" => Order,
    "order_work_detail" => OrderWorkDetail
  }.freeze

  # target_table="order"のproduct_option_idsは実カラムではなく、has_many :through が生成する
  # 集合idsライター（Order#product_option_ids=。Form::ApplicationsController#product_option_field?
  # ／Form::DynamicFormValidatorが特別扱いする申込フォームの選択オプション枠）のため、
  # Order.column_namesには現れない。ホワイトリストへ個別に加える唯一の例外。
  EXTRA_ALLOWED_COLUMNS = {
    "order" => %w[product_option_ids]
  }.freeze

  # SequenceCounterでモデル内部が採番する列（Customer#assign_customer_number／
  # Order#assign_order_number）に加え、決済連携（ネットムーブ会員ID登録）で
  # システムが設定する列。いずれも申込フォーム入力者が上書きできてはならない。
  AUTO_ASSIGNED_COLUMNS = {
    "customer" => %w[customer_number netmove_member_id netmove_registered_at],
    "order" => %w[order_number]
  }.freeze

  # Devise/メールOTP認証に使う列（04 R3残タスク・セキュリティ）。target_tableがcustomerの
  # 場合、これらはCustomer#authenticate_userやOTP検証が参照する認証状態そのものであり、
  # フォーム入力者（営業担当者）が申込フォーム経由で上書きできると、他人のパスワードハッシュや
  # ロック状態・OTPコードを書き換えるアカウント乗っ取りの穴になる。foreign_key・暗号化列の
  # 除外ロジックでは捕捉できないため、列名を直接列挙して一律除外する。
  AUTHENTICATION_COLUMNS = %w[
    encrypted_password
    otp_code_digest otp_code_expires_at otp_attempts
    unlock_token locked_at failed_attempts
  ].freeze

  # 主キー・タイムスタンプ・TracksUser由来の追跡列は、どのtarget_tableでもフォーム入力対象にしない。
  SYSTEM_COLUMNS = %w[id created_at updated_at created_by_id updated_by_id lock_version].freeze

  # ワークフロー制御用の業務ステータス列（Order#status/Customer#status）。新規作成時のデフォルトは
  # assign_default_status等で自動設定される前提で、フォーム入力者が直接指定できてしまうと
  # 「0:受注」等の初期ステータスを飛び越えて任意のOrderStatus/CustomerStatusを自己申告できてしまう
  # （lock_after_statusが本来ガードしたいR4/R5の状態遷移を、新規作成の一撃で迂回できる抜け穴になる）。
  WORKFLOW_STATUS_COLUMNS = %w[status].freeze

  # target_columnホワイトリスト検証（R3レビュー指摘・セキュリティ）: FormField#target_columnは
  # 任意の文字列を許容していたため、フォームビルダー操作者が誤ってagency_id等の所属・紐付け外部キーや
  # OrderWorkDetailのSNS認証情報カラムをtarget_columnに指定すると、申込フォーム経由で
  # 営業担当者がこれらの機密・結線用カラムを直接上書きできてしまっていた（Form::ApplicationSubmissionService
  # がrecord.public_send("#{target_column}=", value)で無条件に反映するため）。
  #
  # 許可カラムは対応モデルの全カラムから、以下を除外して算出する（ハードコードによる二重管理を避けるため
  # 極力動的に導出する）:
  #   - システム列（SYSTEM_COLUMNS）
  #   - 他レコードへの参照キー全般（belongs_to由来のforeign_key。フォーム入力者が書き込むべきでない
  #     結線用カラム。application_submission_serviceが明示的に設定するagency_id/customer_id/store_id/
  #     sales_representative_id/contract_condition_id等はいずれもここに含まれる）
  #   - 暗号化列（Model.encrypted_attributes）
  #     ※ 2026-08-19 CEO決定（Q-45）で ActiveRecord::Encryption の適用を全廃したため、現時点では
  #       常に空集合＝実質no-op。SNS認証情報（instagram_id/pass 等）を申込フォームの入力項目として
  #       必須化する業務要件（2026-08-18浅賀MTG）を満たすために平文化された結果であり、意図どおり。
  #       将来 encrypts を再導入した場合に自動で除外へ戻るよう、判定ロジック自体は残しておく。
  #   - Devise/メールOTP認証列（AUTHENTICATION_COLUMNS。encrypted_password等はbcryptハッシュで
  #     Model.encrypted_attributesには乗らないため上記の暗号化列除外では捕捉できず、別枠で除外する）
  #   - 自動採番列（AUTO_ASSIGNED_COLUMNS。netmove_member_id等の決済連携でシステムが設定する列を含む）
  #   - ワークフロー制御用の業務ステータス列（WORKFLOW_STATUS_COLUMNS）
  # に、product_option_idsのような実カラムでない正規の書き込み先（EXTRA_ALLOWED_COLUMNS）を加える。
  def self.allowed_target_columns_for(target_table)
    model = TARGET_MODELS[target_table]
    return [].freeze if model.blank?

    foreign_keys       = model.reflect_on_all_associations(:belongs_to).map(&:foreign_key)
    encrypted_columns   = model.encrypted_attributes.to_a.map(&:to_s)
    disallowed_columns = SYSTEM_COLUMNS + foreign_keys + encrypted_columns + AUTHENTICATION_COLUMNS +
                          Array(AUTO_ASSIGNED_COLUMNS[target_table]) + WORKFLOW_STATUS_COLUMNS

    (model.column_names - disallowed_columns + Array(EXTRA_ALLOWED_COLUMNS[target_table])).freeze
  end

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
  validate :target_column_must_be_allowed

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

  # target_tableそのものが不正（TARGET_TABLES外）な場合はtarget_table側のバリデーションに任せ、
  # ここでは二重にエラーを積まない。
  def target_column_must_be_allowed
    return if target_column.blank?
    return unless TARGET_TABLES.include?(target_table)
    return if self.class.allowed_target_columns_for(target_table).include?(target_column)

    errors.add(:target_column, "は#{target_table}に割り当てられない列です（#{target_column}）")
  end
end
