# 代理店横断ダッシュボード（04 R6-9・2026-08-20 CEO決定。R6追加タスクの最後の項目）。
# ftlogの/project_overview（稼働中/完了の2分類＋メンバー数・案件数・遅延数等の単純集計。詳細
# レポート機能は無し）を参考に、brige-crmでは「プロジェクト」を持たないため代理店を主語にした
# 横断集計として実装する（要件確定時点でCEOが代理店横断を優先指定）。
#
# 権限: system_admin（admin ロール）専有。全代理店の実績を一望できる集計であり、代理店ユーザー・
# 代理店グループユーザー自身には他社データが混じった横断ビューを見せてはならないため、
# RoleSeeder::SYSTEM_ADMIN_ONLY_CONTROLLERSに登録する（admin/system_settings等と同じ扱い）。
#
# Pundit: 単一のレコード種別を対象にしない集計ビュー（admin/dashboardと同じ理由）のため、
# Admin::BaseController::PUNDIT_VERIFICATION_EXEMPT_CONTROLLERSに登録し、authorize/policy_scopeの
# 代わりにRBAC（SystemPermissionChecker）のみで守る。代理店ごとの内訳を出すが、これは「特定の
# Agencyレコードへの権限確認」ではなく「全代理店を横断してよいか」という一段上の権限（=admin専有）
# の話なので、Punditの対象にする必要はない。
class Admin::AgencyOverviewController < Admin::BaseController
  # idパラメータを持たない単数resource（admin/system_settingsと同じ形）のため #show。
  def show
    completed_codes = OrderStatus.completed.pluck(:code)

    order_totals     = Order.group(:agency_id).count
    completed_totals = Order.where(status: completed_codes).group(:agency_id).count
    # 遅延の定義（自己判断・2026-08-20）: 完了していない（is_completed系ステータスでない）のに
    # work_completed_at（作業完了日）を過ぎている案件。本来work_completed_atは実績日入力欄だが、
    # 未完了のまま過去日が入っている＝入力時に見込んでいた完了日を過ぎても終わっていない状態と
    # 読めるため、新規カラムを追加せずに既存データだけで「わかりやすい遅延の目安」として扱う
    # （タスク仕様が明示した例をそのまま採用。詳細レポートは対象外のため厳密な予定日管理は行わない）。
    delayed_totals = Order.where.not(status: completed_codes)
                           .where("work_completed_at IS NOT NULL AND work_completed_at < ?", Date.current)
                           .group(:agency_id).count
    last_updated_totals = Order.group(:agency_id).maximum(:updated_at)
    member_totals = User.where.not(agency_id: nil).group(:agency_id).count

    @rows = Agency.includes(:agency_group).order(:name).map do |agency|
      total_orders = order_totals[agency.id] || 0
      completed_orders = completed_totals[agency.id] || 0

      {
        agency: agency,
        member_count: member_totals[agency.id] || 0,
        total_orders: total_orders,
        active_orders: total_orders - completed_orders,
        completed_orders: completed_orders,
        delayed_orders: delayed_totals[agency.id] || 0,
        last_updated_at: last_updated_totals[agency.id]
      }
    end
  end
end
