# admin/users の index・show 共通の表示ロジック（アカウント種別バッジの文言・配色）。
module Admin::UsersHelper
  def user_account_type_label(user)
    return "代理店" if user.agency_id.present?
    return "代理店グループ" if user.agency_group_id.present?

    "社内"
  end

  def user_account_type_badge(user)
    color =
      if user.agency_id.present?
        "green"
      elsif user.agency_group_id.present?
        "orange"
      else
        "slate"
      end

    badge_tag(user_account_type_label(user), color: color)
  end
end
