require "rails_helper"

RSpec.describe CustomerNotificationSetting, seed_status_catalog: true do
  let!(:customer) { create(:customer) }

  it "event_typeはNotificationEventType::ALLに含まれる値のみ許可する" do
    setting = build(:customer_notification_setting, customer: customer, event_type: "unknown_event")
    expect(setting).not_to be_valid
    expect(setting.errors[:event_type]).to be_present
  end

  it "同一顧客×同一event_typeは重複できない" do
    create(:customer_notification_setting, customer: customer, event_type: NotificationEventType::APPLICATION_CONFIRMED)
    duplicate = build(:customer_notification_setting, customer: customer,
                       event_type: NotificationEventType::APPLICATION_CONFIRMED)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:event_type]).to be_present
  end

  it "既定値はapp_enabled=true・email_enabled=trueである" do
    expect(CustomerNotificationSetting::DEFAULT_APP_ENABLED).to be(true)
    expect(CustomerNotificationSetting::DEFAULT_EMAIL_ENABLED).to be(true)
  end
end
