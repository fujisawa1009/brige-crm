# admin レイアウトのサイドバーナビゲーション定義（config/routes.rb の admin namespace に対応）。
# 各項目の controller/action は既存の can_access_system_action?（SystemPermissionChecker）に
# そのまま渡し、ルートへのアクセス権限が無い項目はサイドバーにも表示しない
# （画面上の見た目だけ揃えて実際は叩けないリンクを出さないため）。
module AdminNavHelper
  AdminNavSection = Struct.new(:title, :items, keyword_init: true)
  AdminNavItem = Struct.new(:label, :path, :controller, :action, keyword_init: true)

  def admin_nav_sections
    [
      AdminNavSection.new(items: [
        AdminNavItem.new(label: "ダッシュボード", path: admin_dashboard_path,
                          controller: "admin/dashboard", action: "index"),
        AdminNavItem.new(label: "通知設定", path: admin_notification_settings_path,
                          controller: "admin/notification_settings", action: "show")
      ]),
      AdminNavSection.new(title: "ユーザー・権限", items: [
        AdminNavItem.new(label: "ユーザー", path: admin_users_path, controller: "admin/users", action: "index"),
        AdminNavItem.new(label: "ロール管理", path: admin_role_management_index_path,
                          controller: "admin/role_management", action: "index"),
        AdminNavItem.new(label: "権限マトリクス", path: admin_permission_management_path,
                          controller: "admin/permission_management", action: "show"),
        AdminNavItem.new(label: "ログイン履歴", path: admin_login_histories_path,
                          controller: "admin/login_histories", action: "index"),
        AdminNavItem.new(label: "IP許可リスト", path: admin_ip_allowlist_entries_path,
                          controller: "admin/ip_allowlist_entries", action: "index"),
        AdminNavItem.new(label: "システム設定", path: admin_system_settings_path,
                          controller: "admin/system_settings", action: "show")
      ]),
      AdminNavSection.new(title: "組織", items: [
        AdminNavItem.new(label: "代理店グループ", path: admin_agency_groups_path,
                          controller: "admin/agency_groups", action: "index"),
        AdminNavItem.new(label: "代理店", path: admin_agencies_path, controller: "admin/agencies", action: "index"),
        AdminNavItem.new(label: "営業担当者", path: admin_sales_representatives_path,
                          controller: "admin/sales_representatives", action: "index"),
        AdminNavItem.new(label: "契約条件", path: admin_contract_conditions_path,
                          controller: "admin/contract_conditions", action: "index")
      ]),
      AdminNavSection.new(title: "顧客・案件", items: [
        AdminNavItem.new(label: "顧客", path: admin_customers_path, controller: "admin/customers", action: "index"),
        AdminNavItem.new(label: "案件", path: admin_orders_path, controller: "admin/orders", action: "index"),
        AdminNavItem.new(label: "CSVエクスポート", path: admin_csv_exports_path,
                          controller: "admin/csv_exports", action: "index")
      ]),
      AdminNavSection.new(title: "商材マスタ", items: [
        AdminNavItem.new(label: "商材", path: admin_products_path, controller: "admin/products", action: "index"),
        AdminNavItem.new(label: "プラン", path: admin_plans_path, controller: "admin/plans", action: "index"),
        AdminNavItem.new(label: "初期費用", path: admin_product_initial_fees_path,
                          controller: "admin/product_initial_fees", action: "index"),
        AdminNavItem.new(label: "商材オプション", path: admin_product_options_path,
                          controller: "admin/product_options", action: "index"),
        AdminNavItem.new(label: "オプショングループ", path: admin_option_groups_path,
                          controller: "admin/option_groups", action: "index"),
        AdminNavItem.new(label: "オプション値", path: admin_option_values_path,
                          controller: "admin/option_values", action: "index")
      ]),
      AdminNavSection.new(title: "ステータス・ルーティング", items: [
        AdminNavItem.new(label: "顧客ステータス", path: admin_customer_statuses_path,
                          controller: "admin/customer_statuses", action: "index"),
        AdminNavItem.new(label: "案件ステータス", path: admin_order_statuses_path,
                          controller: "admin/order_statuses", action: "index"),
        AdminNavItem.new(label: "契約ステータス", path: admin_contract_statuses_path,
                          controller: "admin/contract_statuses", action: "index"),
        AdminNavItem.new(label: "問い合わせステータス", path: admin_inquiry_statuses_path,
                          controller: "admin/inquiry_statuses", action: "index"),
        AdminNavItem.new(label: "問い合わせ宛先ルート", path: admin_inquiry_recipient_routes_path,
                          controller: "admin/inquiry_recipient_routes", action: "index")
      ]),
      AdminNavSection.new(title: "問い合わせ・通知", items: [
        AdminNavItem.new(label: "問い合わせ", path: admin_inquiries_path, controller: "admin/inquiries", action: "index"),
        AdminNavItem.new(label: "通知送信・履歴", path: admin_notifications_path,
                          controller: "admin/notifications", action: "index"),
        AdminNavItem.new(label: "通知テンプレート", path: admin_notification_templates_path,
                          controller: "admin/notification_templates", action: "index"),
        AdminNavItem.new(label: "宛先グループ", path: admin_recipient_groups_path,
                          controller: "admin/recipient_groups", action: "index")
      ]),
      AdminNavSection.new(title: "その他", items: [
        AdminNavItem.new(label: "フォームテンプレート", path: admin_form_templates_path,
                          controller: "admin/form_templates", action: "index"),
        AdminNavItem.new(label: "重説項目セット", path: admin_disclosure_item_sets_path,
                          controller: "admin/disclosure_item_sets", action: "index"),
        AdminNavItem.new(label: "制作会社", path: admin_production_companies_path,
                          controller: "admin/production_companies", action: "index"),
        AdminNavItem.new(label: "営業資料", path: admin_sales_materials_path,
                          controller: "admin/sales_materials", action: "index")
      ])
    ]
  end

  def visible_admin_nav_sections
    admin_nav_sections.filter_map do |section|
      items = section.items.select { |item| can_access_system_action?(item.controller, item.action) }
      next if items.empty?

      AdminNavSection.new(title: section.title, items: items)
    end
  end
end
