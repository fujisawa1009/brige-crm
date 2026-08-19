# 04 R0-5・02§2-6踏襲: 権限カタログ同期 → 既定ロール作成/権限付与、の順で単一の入口から冪等に実行する。
SystemPermissionSyncService.call
RoleSeeder.call
# 04 R2タスク4: 顧客/案件ステータスマスタの既定値。
StatusSeeder.call
# 04 R3残（form-template-mapping.md §9-2 #1）: BRIDGE_PLUS申込フォームの初期テンプレート67フィールド
# ＋OptionGroup（prefecture/payment_method/yes_no等8種）の投入。全環境で必要な実商材マスタのため
# development限定ブロックの外に置く。
BridgePlusFormTemplateSeeder.call

if Rails.env.development?
  admin_email = "admin@example.com"
  unless User.exists?(email: admin_email)
    admin = User.create!(
      name: "システム管理者",
      email: admin_email,
      password: "Password1234",
      password_confirmation: "Password1234"
    )
    admin_role = SystemRole.find_by!(name: "admin")
    UserSystemRole.create!(user: admin, system_role: admin_role)
    puts "development seed: created #{admin_email} / Password1234 (admin role)"
  end

  # 画面確認用サンプルデータ（顧客約100件など。db/seeds/sample_data.rb参照）。
  load Rails.root.join("db/seeds/sample_data.rb")
end
