# 問い合わせ（04 R4タスク1・2。Laravel Inquiry.php移植＋決定D-11掲示板統合拡張。
# db/migrate/20260815160005参照）。
#
# 掲示板統合（board-implementation-options.md 推奨案①）: 後確/制作対応/検収コールの3種は
# 「案件ステータス遷移に付随する部門間連絡」でステータス選択＝宛先ルーティング、アフター問合せは
# 「分類＋対応者ルーティング付きのタスク管理」という性格の違いを持つが、いずれも
# 「案件番号単位のスレッド＋投稿ごとのステータス変更＝通知トリガー」という共通構造（同§1）を
# 持つため、1モデルに統合しafter_*列で差分だけ表現する（②独立実装は連絡系の二重保守になるため
# 不採用。§3比較表・§5推奨参照）。
#
# ステータスのenum撤廃（同§2-2ギャップ表）: statusはInquiryStatusマスタ（category単位で別集合）を
# 参照する。CustomerStatus/OrderStatusと同じ「マスタ行の存在をバリデーションで担保する」パターン
# （enum型やDB CHECK制約ではなくアプリ層で検証）を踏襲し、運用中の集合追加を権限管理UIから
# 行えるようにする（Column.md系マスタ全般の方針）。
# == Schema Information
#
# Table name: inquiries
#
#  id                     :uuid             not null, primary key
#  after_area             :string
#  after_type             :string
#  after_urgency          :string
#  category               :string           not null
#  first_responder_name   :string
#  inquiry_number         :string           not null
#  is_visible_to_agent    :boolean          default(TRUE), not null
#  is_visible_to_customer :boolean          default(TRUE), not null
#  next_responder_name    :string
#  reception_channel      :string
#  status                 :string           not null
#  title                  :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  created_by_id          :uuid
#  order_id               :uuid             not null
#  updated_by_id          :uuid
#
# Indexes
#
#  index_inquiries_on_category_and_status  (category,status)
#  index_inquiries_on_inquiry_number       (inquiry_number) UNIQUE
#  index_inquiries_on_order_id             (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (order_id => orders.id) ON DELETE => restrict
#  fk_rails_...  (updated_by_id => users.id)
#
class Inquiry < ApplicationRecord
  include TracksUser
  include Auditable

  # board-implementation-options.md §1の呼称をそのまま使う（掲示板4種＝Laravel Inquiry::CATEGORIESを
  # 移植した既存カテゴリと1対1で一致するため、R7移行時のマッピングもこの表記のまま素直に対応できる）。
  CATEGORY_POST_CONFIRM = "後確"
  CATEGORY_PRODUCTION   = "制作対応"
  CATEGORY_INSPECTION   = "検収コール"
  CATEGORY_AFTER        = "アフター問合せ"

  CATEGORIES = [ CATEGORY_POST_CONFIRM, CATEGORY_PRODUCTION, CATEGORY_INSPECTION, CATEGORY_AFTER ].freeze

  # カテゴリ作成時の既定ステータス（board-implementation-options.md §1の各列の先頭値。
  # StatusSeeder(InquiryStatus分)のsort_order=1と一致させること）。
  DEFAULT_STATUS_CODES = {
    CATEGORY_POST_CONFIRM => "対応中",
    CATEGORY_PRODUCTION   => "制作対応中",
    CATEGORY_INSPECTION   => "検収コール対応中",
    CATEGORY_AFTER        => "未対応"
  }.freeze

  belongs_to :order

  has_many :inquiry_messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :inquiry

  before_validation :assign_default_status, on: :create
  before_validation :assign_inquiry_number, on: :create

  validates :inquiry_number, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :status, presence: true
  validate :status_must_exist_in_inquiry_statuses

  # アフター問合せ以外ではアフター固有列を使わない運用だが、DB制約では強制しない
  # （後から他種別で使いたくなった場合の拡張余地を残す。board-implementation-options.md §5の
  # 確認事項「アフター掲示板のカテゴリ3軸は全部必要か」が決定者/業務確認待ちのため、厳格な
  # 排他バリデーションは時期尚早と判断）。

  scope :visible_to_agent, -> { where(is_visible_to_agent: true) }
  # R6-5: 顧客側の表示制御（is_visible_to_agentと対になる独立フラグ）。現時点で顧客が直接
  # Inquiryを閲覧する経路（マイページ等）は存在しない（app/controllers/mypage/配下を確認済み。
  # dashboard/login/OTP/通知設定のみ）ため、このscopeの主な利用箇所はRecipientResolver（宛先の
  # メール絞り込み）。ただし「default_scopeに頼らずクエリのたびに明示する」方針（ftlog横展開調査の
  # 教訓）を踏襲し、将来マイページ等で顧客向け参照経路を追加する際はこのscopeを明示的にチェーンする
  # こと（Inquiry.visible_to_customer を経由しない直接参照を作らない）。
  scope :visible_to_customer, -> { where(is_visible_to_customer: true) }
  scope :for_category, ->(category) { where(category: category) }

  # ステータス駆動の宛先ルーティング解決（board-implementation-options.md §2-2「ステータス
  # （or次回対応者）選択＝宛先自動決定」）。RecipientResolverへの薄い委譲。
  def routed_recipient_groups
    RecipientResolver.route_for(category: category, status_code: status)
  end

  private

  def assign_default_status
    self.status = DEFAULT_STATUS_CODES.fetch(category, nil) if status.blank? && category.present?
  end

  def assign_inquiry_number
    return if inquiry_number.present?

    self.inquiry_number = format("INQ-%06d", SequenceCounter.next_value!("inquiry_number"))
  end

  def status_must_exist_in_inquiry_statuses
    return if category.blank? || status.blank?
    return if InquiryStatus.exists?(category: category, code: status)

    errors.add(:status, "はinquiry_statusesに存在しないコードです（#{category}/#{status}）")
  end
end
