require "rails_helper"

# R6-1: 個人ごとの通知設定（E1申込受付）が StaffNotificationMailer の宛先絞り込みに
# 反映されることを検証する（判定はNotificationSettingGateに集約）。
RSpec.describe StaffNotificationMailer, type: :mailer, seed_status_catalog: true do
  let!(:role) { create(:system_role, name: "実務運用者", system: true) }
  let!(:staff_a) { create(:user, email: "staff-a@example.com") }
  let!(:staff_b) { create(:user, email: "staff-b@example.com") }
  let!(:order) { create(:order) }

  before do
    UserSystemRole.create!(user: staff_a, system_role: role)
    UserSystemRole.create!(user: staff_b, system_role: role)
    ActionMailer::Base.deliveries.clear
  end

  it "設定が無いユーザーには既定値（email ON）で届く" do
    described_class.new_application(order).deliver_now
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly("staff-a@example.com", "staff-b@example.com")
  end

  it "E1のメール通知をOFFにしたユーザーは宛先から除外される" do
    create(:staff_notification_setting, user: staff_b,
           event_type: NotificationEventType::APPLICATION_RECEIVED, email_enabled: false)

    described_class.new_application(order).deliver_now
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly("staff-a@example.com")
  end

  it "app_enabledをOFFにしてもメール送信には影響しない（チャネルは独立に判定する）" do
    create(:staff_notification_setting, user: staff_b,
           event_type: NotificationEventType::APPLICATION_RECEIVED, app_enabled: false, email_enabled: true)

    described_class.new_application(order).deliver_now
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly("staff-a@example.com", "staff-b@example.com")
  end

  it "全員がOFFなら送信自体が行われない" do
    [ staff_a, staff_b ].each do |staff|
      create(:staff_notification_setting, user: staff,
             event_type: NotificationEventType::APPLICATION_RECEIVED, email_enabled: false)
    end

    described_class.new_application(order).deliver_now
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
