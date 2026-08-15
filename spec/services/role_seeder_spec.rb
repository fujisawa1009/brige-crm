require "rails_helper"

RSpec.describe RoleSeeder do
  before { SystemPermissionSyncService.call }

  it "組み込み4ロールを冪等に作成する（Laravel現行の名称を維持）" do
    expect { described_class.call }.to change(SystemRole, :count).from(0).to(4)
    expect(SystemRole.pluck(:name)).to contain_exactly("admin", "実務運用者", "代理店グループ用", "代理店用")

    expect { described_class.call }.not_to change(SystemRole, :count) # 2回目は増えない
  end

  it "adminロールはsuper_admin=trueで組み込みロールになる" do
    described_class.call
    admin = SystemRole.find_by!(name: "admin")
    expect(admin.super_admin?).to eq(true)
    expect(admin.system?).to eq(true)
  end

  it "admin以外の3ロールにはadmin/dashboardの権限が既定付与される" do
    described_class.call

    %w[実務運用者 代理店グループ用 代理店用].each do |name|
      role = SystemRole.find_by!(name: name)
      expect(role.system_permissions.pluck(:controller)).to include("admin/dashboard")
    end
  end

  it "grantは追加のみで、既存の割当を剥奪しない" do
    described_class.call
    role = SystemRole.find_by!(name: "実務運用者")
    # 04 R1でR1_ORGANIZATION_CONTROLLERSが既定付与されたため、「admin/dashboard以外」だけでは
    # 既に付与済みの権限を拾ってしまう可能性がある。まだ付与されていない権限を明示的に選ぶ。
    extra_permission = SystemPermission.enabled.admin.where.not(id: role.system_permissions.select(:id)).first
    SystemRolePermission.create!(system_role: role, system_permission: extra_permission)

    described_class.call

    expect(role.reload.system_permissions).to include(extra_permission)
  end
end
