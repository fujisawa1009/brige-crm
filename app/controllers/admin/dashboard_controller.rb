# R0完了条件の検証対象画面（04「ダッシュボード1画面がログイン→OTP→権限チェック→表示を通過」）。
# 全ロールに既定付与される唯一の画面（RoleSeeder::SELF_SERVICE_CONTROLLERS）。
class Admin::DashboardController < Admin::BaseController
  # 件数カード。controller/action は can_access_system_action? に渡し、その操作を許可されていない
  # ロールにはカード自体を出さない（表示レイヤーだけ揃えて実際は叩けない導線を作らないため）。
  # policy_scope で件数を数えるのは、AgencyScoped（03§6）の代理店/代理店グループ絞り込みを
  # ここでも一覧画面と同じ基準で効かせるため（staffは全件、代理店ユーザーは自代理店分のみ表示）。
  STAT_CARDS = [
    { label: "顧客", icon: :customers, model: Customer, controller: "admin/customers", path_helper: :admin_customers_path },
    { label: "案件", icon: :orders, model: Order, controller: "admin/orders", path_helper: :admin_orders_path },
    { label: "問い合わせ", icon: :inquiries, model: Inquiry, controller: "admin/inquiries", path_helper: :admin_inquiries_path },
    { label: "代理店", icon: :agencies, model: Agency, controller: "admin/agencies", path_helper: :admin_agencies_path }
  ].freeze

  def index
    @stat_cards = STAT_CARDS.filter_map do |card|
      next unless can_access_system_action?(card[:controller], "index")

      {
        label: card[:label],
        icon: card[:icon],
        count: policy_scope(card[:model]).count,
        path: send(card[:path_helper])
      }
    end
  end
end
