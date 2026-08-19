# システム設定（R6-3・2026-08-20 CEO決定）。ftlogにある「組織ごとの設定」に相当する概念だが、
# brige-crmはシングルテナントのため組織単位の設定は不要で、代わりにアプリ全体で1行のみを持つ
# シングルトンとして実装する。Rails.cacheは使わない（CEO指示のシンプル方針。管理画面からの
# 参照頻度は低く、毎回1SELECTで十分）。
#
# 対象範囲（実装時の判断。詳細は requirements/design/04-rails-implementation-plan.md R6-3参照）:
#   - 問い合わせ添付ファイルの上限（従来 InquiryMessage の class 定数だったもの。R6-3でDB管理へ切替）
# 「案件種別・問い合わせ種別のマスタ初期値」は、対象コードが is_system 保護つきの業務ロジック定数
# （OrderStatus::CODE_ORDERED 等。master-data-design-policy.md §1-1）と直結しており、動的に
# 差し替え可能にすると状態機械の前提が壊れるリスクがあるため今回は対象外とし、Admin::SystemSettingsController
# からは各マスタ画面（案件ステータス・問い合わせステータス・選択肢マスタ）への導線のみを提供する。
#
# == Schema Information
#
# Table name: system_settings
#
#  id                             :uuid             not null, primary key
#  inquiry_attachment_max_count   :integer          default(5), not null
#  inquiry_attachment_max_size_mb :integer          default(50), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  created_by_id                  :uuid
#  updated_by_id                  :uuid
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class SystemSetting < ApplicationRecord
  include TracksUser
  include Auditable

  validates :inquiry_attachment_max_count, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :inquiry_attachment_max_size_mb, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 500 }
  validate :only_one_record_may_exist, on: :create

  # シングルトン取得。存在しなければカラムのDB既定値で1行作る（find_or_create的な設計。
  # 複数プロセスからの同時初回アクセスで稀に競合しうるが、管理設定という性質上ユニーク制約による
  # 厳密な排他までは不要と判断＝only_one_record_may_exist（アプリ層のガード）で十分とする）。
  def self.current
    first_or_create!
  end

  def inquiry_attachment_max_size_bytes
    inquiry_attachment_max_size_mb.megabytes
  end

  # Auditable#audit_record の resource_label フォールバック用（name/display_name/cidrを
  # 持たないため、無指定だとログの資源名列が空欄になってしまう）。
  def display_name = "システム設定"

  private

  def only_one_record_may_exist
    errors.add(:base, "システム設定は1件のみ作成できます") if self.class.exists?
  end
end
