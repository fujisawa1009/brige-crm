require "rails_helper"

# == Schema Information
#
# Table name: staff_notification_settings
#
#  id            :uuid             not null, primary key
#  app_enabled   :boolean          default(TRUE), not null
#  email_enabled :boolean          default(TRUE), not null
#  event_type    :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :uuid             not null
#
# Indexes
#
#  index_staff_notification_settings_on_user_and_event  (user_id,event_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
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
