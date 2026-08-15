# CSV非同期エクスポートのジョブ状態・成果物（04 R2タスク7）。CsvExportJobが非同期に生成する。
# requested_byだけが自分のエクスポートをダウンロードできる（Admin::CsvExportsController参照。
# 他ユーザーの案件一覧CSVを覗き見できてしまうとPunditスコープを迂回した情報漏えい経路になるため）。
# == Schema Information
#
# Table name: csv_exports
#
#  id              :uuid             not null, primary key
#  error_message   :text
#  file_data       :text
#  resource_type   :string           not null
#  row_count       :integer
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  requested_by_id :uuid             not null
#
# Indexes
#
#  index_csv_exports_on_requested_by_id  (requested_by_id)
#  index_csv_exports_on_status           (status)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#
class CsvExport < ApplicationRecord
  belongs_to :requested_by, class_name: "User"

  # 04 R2で対応するリソース種別のみ許可する（任意モデル名を受け付けるとpolicy_scope経由でない
  # 任意テーブルのダンプに悪用されうるため許可リストにする）。
  EXPORTABLE_RESOURCE_TYPES = %w[Customer Order].freeze

  validates :resource_type, presence: true, inclusion: { in: EXPORTABLE_RESOURCE_TYPES }
  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }

  scope :pending, -> { where(status: "pending") }
end
