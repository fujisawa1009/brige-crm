require "rails_helper"

RSpec.describe StaffNotificationSetting do
  let!(:user) { create(:user) }

  it "event_typeはNotificationEventType::ALLに含まれる値のみ許可する" do
    setting = build(:staff_notification_setting, user: user, event_type: "unknown_event")
    expect(setting).not_to be_valid
    expect(setting.errors[:event_type]).to be_present
  end

  it "同一ユーザー×同一event_typeは重複できない" do
    create(:staff_notification_setting, user: user, event_type: NotificationEventType::APPLICATION_RECEIVED)
    duplicate = build(:staff_notification_setting, user: user, event_type: NotificationEventType::APPLICATION_RECEIVED)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:event_type]).to be_present
  end

  it "既定値はapp_enabled=true・email_enabled=trueである" do
    expect(StaffNotificationSetting::DEFAULT_APP_ENABLED).to be(true)
    expect(StaffNotificationSetting::DEFAULT_EMAIL_ENABLED).to be(true)
  end
end
