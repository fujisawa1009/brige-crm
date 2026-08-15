require "rails_helper"

# TracksUser concern（04 R0-8）。Current.userからcreated_by/updated_byを自動セットする。
# SystemRole/IpAllowlistEntry（admin編集対象リソース）に適用済み。
RSpec.describe "TracksUser", type: :model do
  let(:actor) { create(:user) }

  around do |example|
    Current.set(user: actor) { example.run }
  end

  it "作成時にCurrent.userからcreated_by/updated_byを自動セットする（SystemRole）" do
    role = SystemRole.create!(name: "spec-role-#{SecureRandom.hex(4)}", display_name: "spec", system: false)
    expect(role.created_by).to eq(actor)
    expect(role.updated_by).to eq(actor)
  end

  it "更新時にupdated_byだけを差し替える（created_byは維持）" do
    role = SystemRole.create!(name: "spec-role-#{SecureRandom.hex(4)}", display_name: "spec", system: false)
    other = create(:user)

    Current.set(user: other) { role.update!(display_name: "renamed") }

    expect(role.reload.created_by).to eq(actor)
    expect(role.updated_by).to eq(other)
  end

  it "IpAllowlistEntryにも同様に適用される" do
    entry = IpAllowlistEntry.create!(cidr: "203.0.113.0/24")
    expect(entry.created_by).to eq(actor)
  end
end
