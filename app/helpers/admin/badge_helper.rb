# R6-2 共通UIパーツ化: admin配下の全バッジ表示が経由する共通の土台ヘルパー。
# 各リソース別ヘルパー（customer_status_badge等）は「codeからcolor(配色キー)を引く」
# ロジックだけを持ち、実際のタグ生成はここへ委譲することで、
# 「tag.spanで完成したHTMLタグを返す」シグネチャを全バッジで統一する。
# 色の見た目自体はapp/assets/tailwind/application.cssの`@layer components`（.badge-*）が持つ。
module Admin::BadgeHelper
  BADGE_COLORS = %w[blue green amber red purple orange slate slate-muted].freeze

  def badge_tag(label, color:)
    color = color.to_s
    color = "slate" unless BADGE_COLORS.include?(color)

    tag.span label, class: "badge badge-#{color}"
  end
end
