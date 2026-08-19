require "rails_helper"

# R6-1: 個人ごとの通知設定（E2申込確認）が Form::ApplicationMailer の送信可否に
# 反映されることを検証する（判定はNotificationSettingGateに集約）。
RSpec.describe Form::ApplicationMailer, type: :mailer, seed_status_catalog: true do
  let!(:agency) { create(:agency) }
  let!(:customer) { create(:customer, agency: agency, email: "customer@example.com") }
  let!(:order) { create(:order, agency: agency, customer: customer) }
  let!(:application) { create(:application, agency: agency, customer: customer, order: order) }

  before { ActionMailer::Base.deliveries.clear }

  it "設定が無い顧客には既定値（email ON）で届く" do
    described_class.confirmation(application).deliver_now
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly("customer@example.com")
  end

  it "E2のメール通知をOFFにした顧客には送信されない" do
    create(:customer_notification_setting, customer: customer,
           event_type: NotificationEventType::APPLICATION_CONFIRMED, email_enabled: false)

    described_class.confirmation(application).deliver_now
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
