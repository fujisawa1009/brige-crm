# admin/users の index・show 共通の表示ロジック（アカウント種別バッジの文言・配色）。
module Admin::UsersHelper
  def user_account_type_label(user)
    return "代理店" if user.agency_id.present?
    return "代理店グループ" if user.agency_group_id.present?

    "社内"
  end

  def user_account_type_badge_class(user)
    return "bg-green-100 text-green-700" if user.agency_id.present?
    return "bg-orange-100 text-orange-700" if user.agency_group_id.present?

    "bg-slate-100 text-slate-600"
  end
end
