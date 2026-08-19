# admin/csv_exports の処理状況バッジ。R6-2でビュー直書きのcase文をヘルパーへ集約し、
# 他のバッジ群と同じくtag.spanで完成したHTMLタグを返す形に統一。
module Admin::CsvExportsHelper
  STATUS_LABELS = {
    "completed" => "完了",
    "failed" => "失敗",
    "pending" => "処理中"
  }.freeze

  STATUS_BADGE_COLORS = {
    "completed" => "green",
    "failed" => "red"
  }.freeze

  def csv_export_status_badge(status)
    label = STATUS_LABELS.fetch(status, status)
    color = STATUS_BADGE_COLORS.fetch(status, "amber")

    badge_tag(label, color: color)
  end
end
