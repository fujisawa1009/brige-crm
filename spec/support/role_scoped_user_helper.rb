# request spec 共通ヘルパー: 組み込みロール(SystemRole)を割り当てたUserを1行で作る（04 R1の
# 参照制御specで「admin/実務運用者/代理店グループ用/代理店用」の4種を毎回書くと冗長なため抽出）。
# 呼び出し側は `seed_permission_catalog: true`（RoleSeederが組み込みロールを作成済み）を前提とする。
module RoleScopedUserHelper
  def user_with_role(role_name, **attrs)
    role = SystemRole.find_by!(name: role_name)
    create(:user, **attrs).tap { |u| UserSystemRole.create!(user: u, system_role: role) }
  end
end

RSpec.configure do |config|
  config.include RoleScopedUserHelper, type: :request
end
