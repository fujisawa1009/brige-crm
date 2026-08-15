require "set"

# 認可（SystemPermissionChecker）のrequest spec既定挙動（04 R0-9。ftlog移植）。
#
# 既定=実認可（フェイルクローズ）。フェイルオープン（常にtrueにスタブ）が必要な既存specは
# fail_open_request_specs.txt に載せて据え置く段階移行の仕組みだが、brige-crmはR0が最初のspecのため
# 当面このリストは空のまま運用する（新規specは実認可で書く）。
#
# example単位の優先順位:
#   1. :system_authorization タグ        → 実認可（明示的に権限を通す。既定と同じだが意図の明示に使う）
#   2. :skip_system_authorization タグ   → スタブ（一時的にバイパスしたい新規specのオプトアウト）
#   3. 許可リストのファイル               → スタブ（レガシーのフェイルオープン据え置き。R0では空）
#   4. 上記以外（既定）                   → 実認可
FAIL_OPEN_REQUEST_SPECS = begin
  path = File.expand_path("fail_open_request_specs.txt", __dir__)
  File.readlines(path, chomp: true)
      .reject { |line| line.empty? || line.start_with?("#") }
      .to_set
end

# :seed_permission_catalog タグを付けると、example冒頭で権限カタログ（SystemPermission）を
# ルート定義から同期し、RoleSeeder相当の既定権限マトリクスを組み込みロールへ付与する。
module SystemPermissionSeedHelpers
  def seed_permission_catalog!
    SystemPermissionSyncService.call
    RoleSeeder.call
  end

  # 指定コントローラー（と任意でaction絞り込み）の有効な権限をロールへ付与する。
  # 例: grant_system_permissions!(role, "admin/ip_allowlist_entries")
  #     grant_system_permissions!(role, "admin/role_management", actions: %w[destroy])
  def grant_system_permissions!(role, *controllers, actions: nil)
    perms = SystemPermission.enabled.where(controller: controllers)
    perms = perms.where(action: actions) if actions
    perms.find_each do |perm|
      SystemRolePermission.find_or_create_by!(system_role: role, system_permission: perm)
    end
  end

  # 指定ロールから、指定コントローラーの権限割当をすべて剥奪する（403 spec用ヘルパー）。
  def revoke_system_permissions!(role, *controllers)
    perms = SystemPermission.where(controller: controllers)
    SystemRolePermission.where(system_role: role, system_permission: perms).destroy_all
  end
end

RSpec.configure do |config|
  config.include SystemPermissionSeedHelpers, type: :request

  config.before(:each, :seed_permission_catalog) do
    seed_permission_catalog!
  end

  config.before(:each, type: :request) do |example|
    stub_authorization =
      if example.metadata[:system_authorization]
        false
      elsif example.metadata[:skip_system_authorization]
        true
      else
        spec_file = example.metadata[:file_path].to_s.sub(%r{\A\./}, "")
        FAIL_OPEN_REQUEST_SPECS.include?(spec_file)
      end

    allow(SystemPermissionChecker).to receive(:allowed?).and_return(true) if stub_authorization
  end
end
