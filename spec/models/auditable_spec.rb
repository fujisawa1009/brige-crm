require "rails_helper"

# Auditable concern（04 R0-7）。モデルのフィールド変更をAuditLogへ記録する。
RSpec.describe "Auditable", type: :model do
  let(:actor) { create(:user) }

  around do |example|
    Current.set(user: actor) { example.run }
  end

  it "作成時にAuditLog(created)を記録する" do
    role = SystemRole.create!(name: "spec-role-#{SecureRandom.hex(4)}", display_name: "spec", system: false)

    log = AuditLog.for_resource("SystemRole", role.id).find_by(action: "created")
    expect(log).to be_present
    expect(log.user_id).to eq(actor.id)
    expect(log.changes_after["display_name"]).to eq("spec")
  end

  it "追跡対象フィールドの更新時にAuditLog(updated)を差分付きで記録する" do
    role = SystemRole.create!(name: "spec-role-#{SecureRandom.hex(4)}", display_name: "before", system: false)
    role.update!(display_name: "after")

    log = AuditLog.for_resource("SystemRole", role.id).find_by(action: "updated")
    expect(log.changes_before["display_name"]).to eq("before")
    expect(log.changes_after["display_name"]).to eq("after")
  end

  it "追跡対象外フィールドのみの更新ではAuditLogを増やさない" do
    role = SystemRole.create!(name: "spec-role-#{SecureRandom.hex(4)}", display_name: "before", system: false)

    expect do
      role.update!(position: 99)
    end.not_to change { AuditLog.for_resource("SystemRole", role.id).where(action: "updated").count }
  end

  # 04 R4追補: InquiryMessage は Auditable を include しているにもかかわらず TRACKED_FIELDS に
  # エントリが無く、作成イベントが空のchanges_afterで記録されるだけになっていた
  # （app/models/concerns/auditable.rb冒頭コメント「bodyは除外・構造的な列のみ追跡」との不整合）。
  # inquiry_id を追跡対象に加えた修正を確認する。
  it "InquiryMessageは作成時にinquiry_idをAuditLogへ記録し、本文(body)は記録しない", :seed_status_catalog do
    inquiry = create(:inquiry)
    message = inquiry.inquiry_messages.create!(body: "本文はログに残らないこと")

    log = AuditLog.for_resource("InquiryMessage", message.id).find_by(action: "created")
    expect(log).to be_present
    expect(log.changes_after).to eq("inquiry_id" => inquiry.id)
    expect(log.changes_after).not_to have_key("body")
  end
end
