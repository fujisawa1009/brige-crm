# admin/inquiry_statuses・admin/inquiry_recipient_routes で共通の掲示板種別バッジ配色。
module Admin::InquiryCategoriesHelper
  CATEGORY_BADGE_CLASSES = {
    Inquiry::CATEGORY_POST_CONFIRM => "bg-blue-100 text-blue-700",
    Inquiry::CATEGORY_PRODUCTION => "bg-purple-100 text-purple-700",
    Inquiry::CATEGORY_INSPECTION => "bg-amber-100 text-amber-700",
    Inquiry::CATEGORY_AFTER => "bg-green-100 text-green-700"
  }.freeze

  def inquiry_category_badge_class(category)
    CATEGORY_BADGE_CLASSES.fetch(category, "bg-slate-100 text-slate-600")
  end
end
