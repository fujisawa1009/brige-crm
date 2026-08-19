# 問い合わせ返信テンプレート（R6-4。legacy-research/13-faq-templates.md F-1〜F-4の実装）。
# FAQ 318件・12カテゴリ（同書§1）のマスタ。実データ投入はR7（データ投入）と合わせて実施し、
# ここではカテゴリ×テンプレート本文（差し込み変数対応）のCRUD基盤のみを用意する。
#
# 差し込み変数の展開は本モデルではなく InquiryTemplateRenderer（app/services）に持たせる
# （「テンプレート定義」と「特定のInquiryへの展開」を分離し、展開ロジックを差し替え・単体テストしやすくするため）。
# == Schema Information
#
# Table name: inquiry_templates
#
#  id            :uuid             not null, primary key
#  body          :text             not null
#  category      :string           not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_inquiry_templates_on_category  (category)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class InquiryTemplate < ApplicationRecord
  include TracksUser
  include Auditable

  # legacy-research/13-faq-templates.md §1のFAQ12カテゴリをそのまま列挙する（実データ投入前のR6-4時点では
  # カテゴリ名の揺れを防ぐため固定リストで運用し、業務側から新カテゴリの要望が出た時点で追加する）。
  CATEGORIES = [
    "ログイン情報関連",
    "口コミ一覧・返信機能",
    "ダッシュボードについて",
    "反映挙動・時間関連",
    "Instagram新規投稿作成機能",
    "自動返信設定",
    "口コミ承認設定機能",
    "最新情報の定型文やボタンリンク",
    "通知関連",
    "ハッシュタグ削除機能",
    "Facebook（通常）連携について",
    "除外文言関連"
  ].freeze

  has_many :inquiry_messages, dependent: :nullify, inverse_of: :inquiry_template

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :name, presence: true, length: { maximum: 255 }
  validates :body, presence: true
end
