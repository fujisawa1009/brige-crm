require "rails_helper"

RSpec.describe SystemPermissionSyncService do
  it "ルート定義からSystemPermissionを冪等に同期する" do
    expect { described_class.call }.to change(SystemPermission, :count).from(0)

    result = described_class.call
    expect(result.created).to eq(0) # 2回目は新規作成なし（冪等）
  end

  it "admin/form/mypageの3区分でsectionを自動判定する（決定C）" do
    described_class.call

    dashboard = SystemPermission.find_by(controller: "admin/dashboard", action: "index")
    expect(dashboard.section).to eq("admin")
  end

  it "devise系ルートは権限カタログから除外される" do
    described_class.call

    expect(SystemPermission.where(controller: "devise/sessions")).not_to exist
  end
end
