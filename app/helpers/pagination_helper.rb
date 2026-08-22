# 一覧画面の共通ページネーション（CEO指示 2026-08-20 タスクC）のロジック側。
# R6-2で確立した「Helper=ロジック / CSS=見た目」方針に従い、文言の組み立てはここ、
# 配色・形状は app/assets/tailwind/application.css の .pagination-* が持つ。
# ビューは app/views/shared/_pagination.html.erb（admin配下の全一覧画面から呼ぶ）。
module PaginationHelper
  # 「全 80 件中 1〜25 件を表示」。0件ヒット時も欠けた表示にならないよう専用の文言を返す
  # （pagy.from / pagy.to は0件のとき 0 を返すため、そのまま埋めると「0〜0 件を表示」になる）。
  def pagination_summary(pagy)
    return "全 0 件" if pagy.blank? || pagy.count.to_i.zero?

    "全 #{number_with_delimiter(pagy.count)} 件中 " \
      "#{number_with_delimiter(pagy.from)}〜#{number_with_delimiter(pagy.to)} 件を表示"
  end
end
