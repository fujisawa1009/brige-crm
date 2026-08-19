require "rails_helper"

# R6-1: 個人ごとの通知設定（E4/E9/E10案件関連の通知）が InquiryNotifier のアプリ内通知作成に
# 反映されることを検証する（判定はNotificationSettingGateに集約）。
RSpec.describe InquiryNotifier, seed_status_catalog: true do
  let!(:agency) { create(:agency) }
  let!(:customer) { create(:customer, agency: agency) }
  let!(:order) { create(:order, agency: agency, customer: customer) }
  let!(:inquiry) { create(:inquiry, order: order) }
  let!(:staff_user) { create(:user) }
  let!(:message) { create(:inquiry_message, inquiry: inquiry) }

  before do
    message.assign_recipients!([
      { type: "User", id: staff_user.id },
      { type: "Customer", id: customer.id }
    ])
  end

  it "設定が無い受信者には既定値（app ON）でアプリ内通知が作られる" do
    expect {
      described_class.notify_message_created(message)
    }.to change(SystemNotification, :count).by(2)
  end

  it "E4/E9/E10のアプリ内通知をOFFにした受信者には作られない" do
    create(:staff_notification_setting, user: staff_user,
           event_type: NotificationEventType::INQUIRY_CASE_RELATED, app_enabled: false)

    expect {
      described_class.notify_message_created(message)
    }.to change(SystemNotification, :count).by(1)

    expect(SystemNotification.where(recipient: staff_user)).to be_empty
    expect(SystemNotification.where(recipient: customer)).to be_present
  end

  it "顧客側もOFFにすれば顧客のアプリ内通知は作られない" do
    create(:customer_notification_setting, customer: customer,
           event_type: NotificationEventType::INQUIRY_CASE_RELATED, app_enabled: false)

    described_class.notify_message_created(message)

    expect(SystemNotification.where(recipient: customer)).to be_empty
    expect(SystemNotification.where(recipient: staff_user)).to be_present
  end
end
