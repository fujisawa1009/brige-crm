# 04 R0-5・02§2-6踏襲: 権限カタログ同期 → 既定ロール作成/権限付与、の順で単一の入口から冪等に実行する。
SystemPermissionSyncService.call
RoleSeeder.call
# 04 R2タスク4: 顧客/案件ステータスマスタの既定値。
StatusSeeder.call
# 04 R4追補「リスク・注意」7: 問い合わせ宛先（RecipientGroup / InquiryRecipientRoute）の初期データ。
# InquiryRecipientRoute は inquiry_statuses に存在するコードしか受け付けないため StatusSeeder の後。
InquiryRecipientSeeder.call
# 04 R3残（form-template-mapping.md §9-2 #1）: BRIDGE_PLUS申込フォームの初期テンプレート67フィールド
# ＋OptionGroup（prefecture/payment_method/yes_no等8種）の投入。全環境で必要な実商材マスタのため
# development限定ブロックの外に置く。
BridgePlusFormTemplateSeeder.call

# Laravel版シーダー移植（ProductSeeder / AgencyGroupSeeder / AgencySeeder）: 本番CSV由来の
# 商材・プラン・代理店グループ・代理店の実データマスタ。全環境で必要なため development 限定の外に置く。
# 実行順序: 商材 → 代理店グループ → 代理店（代理店は group_code / BRIDGE_PLUS 商材へ依存）。
load Rails.root.join("db/seeds/products.rb")
load Rails.root.join("db/seeds/agency_groups.rb")
load Rails.root.join("db/seeds/agencies.rb")

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

  # 画面確認用サンプルデータ（顧客・案件・問い合わせ）。実データの代理店・商材に紐づけて生成する
  # （db/seeds/sample_transactions.rb参照。7e12d94で廃止された旧sample_data.rbの復元）。
  load Rails.root.join("db/seeds/sample_transactions.rb")
end
