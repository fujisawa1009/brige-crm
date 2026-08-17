require "rails_helper"

# 04 R4タスク3: 一斉通知の実送信ジョブ。宛先解決→NotificationRecipient作成→送信成否記録→
# 集計更新までの一連を検証する（一部宛先の失敗が全体を止めないことを含む）。
RSpec.describe NotificationDeliveryJob, type: :job, seed_status_catalog: true do
  before { ActionMailer::Base.deliveries.clear }

  it "代理店宛通知を解決して送信し、成功件数・ステータスを更新する" do
    group = create(:agency_group)
    create(:agency, agency_group: group, email_1: "a1@example.com")
    create(:agency, agency_group: group, email_1: "a2@example.com")
    create(:agency, agency_group: group) # メールなし→除外される
    notification = create(:notification, target_type: Notification::TARGET_AGENCY)

    described_class.perform_now(notification.id)

    notification.reload
    expect(notification.status).to eq(Notification::STATUS_SENT)
    expect(notification.total_count).to eq(2)
    expect(notification.success_count).to eq(2)
    expect(notification.notification_recipients.count).to eq(2)
    expect(ActionMailer::Base.deliveries.size).to eq(2)
  end

  it "顧客宛通知はfilter_paramsのstatusで絞り込める" do
    agency = create(:agency)
    create(:customer, agency: agency, email: "c1@example.com", status: "contracted")
    create(:customer, agency: agency, email: "c2@example.com", status: "applied")
    notification = create(:notification, target_type: Notification::TARGET_CUSTOMER,
                                         filter_params: { "status" => "contracted" })

    described_class.perform_now(notification.id)

    expect(notification.reload.success_count).to eq(1)
    expect(ActionMailer::Base.deliveries.first.to).to include("c1@example.com")
  end

  it "送信失敗はNotificationRecipientにfailedとして記録され、全体は止まらない" do
    agency = create(:agency)
    create(:customer, agency: agency, email: "c1@example.com")
    create(:customer, agency: agency, email: "c2@example.com")
    notification = create(:notification, target_type: Notification::TARGET_CUSTOMER)

    call_count = 0
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now) do
      call_count += 1
      raise StandardError, "boom" if call_count == 1
    end

    described_class.perform_now(notification.id)

    notification.reload
    expect(notification.total_count).to eq(2)
    expect(notification.failed_count).to eq(1)
    expect(notification.success_count).to eq(1)
    expect(notification.notification_recipients.where(status: NotificationRecipient::STATUS_FAILED).count).to eq(1)
  end
end
