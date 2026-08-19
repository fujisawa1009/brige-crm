# admin/inquiry_statuses・admin/inquiry_recipient_routes・admin/inquiries で共通の
# 掲示板種別バッジ。R6-2でtag.spanを返す形に統一。
module Admin::InquiryCategoriesHelper
  CATEGORY_BADGE_COLORS = {
    Inquiry::CATEGORY_POST_CONFIRM => "blue",
    Inquiry::CATEGORY_PRODUCTION => "purple",
    Inquiry::CATEGORY_INSPECTION => "amber",
    Inquiry::CATEGORY_AFTER => "green"
  }.freeze

  def inquiry_category_badge(category)
    badge_tag(category, color: CATEGORY_BADGE_COLORS.fetch(category, "slate"))
  end
end
