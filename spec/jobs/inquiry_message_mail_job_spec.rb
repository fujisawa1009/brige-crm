require "rails_helper"

# 04 R4タスク1: 問い合わせメール送信ジョブ（Laravel SendInquiryMessageJob 移植）。
# 宛先ごとにメールを送り、最初に成功したアドレスを resolved_email に記録すること、
# 1宛先の失敗が他宛先の送信を止めないことを検証する。
RSpec.describe InquiryMessageMailJob, type: :job, seed_status_catalog: true do
  include ActiveJob::TestHelper

  let(:agency) { create(:agency, email_1: "agency@example.com") }
  let(:customer) { create(:customer, agency: agency, email: "customer@example.com") }
  let(:order) { create(:order, agency: agency, customer: customer) }
  let(:inquiry) { create(:inquiry, order: order) }
  let(:message) { create(:inquiry_message, inquiry: inquiry) }

  before { ActionMailer::Base.deliveries.clear }

  it "宛先ごとにメールを送信し、resolved_email に代表アドレスを記録する" do
    recipient = message.inquiry_message_recipients.create!(recipient_type: "Agency", recipient_id: agency.id)

    perform_enqueued_jobs { described_class.perform_now(message.id) }

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    mail = ActionMailer::Base.deliveries.first
    expect(mail.to).to include("agency@example.com")
    expect(mail.subject).to include(inquiry.inquiry_number)
    expect(recipient.reload.resolved_email).to eq("agency@example.com")
  end

  it "複数宛先へ送る（Agency と Customer）" do
    message.inquiry_message_recipients.create!(recipient_type: "Agency", recipient_id: agency.id)
    message.inquiry_message_recipients.create!(recipient_type: "Customer", recipient_id: customer.id)

    described_class.perform_now(message.id)

    tos = ActionMailer::Base.deliveries.flat_map(&:to)
    expect(tos).to contain_exactly("agency@example.com", "customer@example.com")
  end

  it "メールを持たない宛先は送信されず resolved_email も記録されない" do
    no_mail_agency = create(:agency) # email列すべてnil
    recipient = message.inquiry_message_recipients.create!(recipient_type: "Agency", recipient_id: no_mail_agency.id)

    described_class.perform_now(message.id)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(recipient.reload.resolved_email).to be_nil
  end

  it "1宛先の送信失敗が他宛先の送信を止めない（失敗はログに残して続行）" do
    message.inquiry_message_recipients.create!(recipient_type: "Agency", recipient_id: agency.id)
    message.inquiry_message_recipients.create!(recipient_type: "Customer", recipient_id: customer.id)

    # Agency宛(=最初)だけ配送を失敗させ、Customer宛は成功することを確認する。
    call_count = 0
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now) do
      call_count += 1
      raise StandardError, "boom" if call_count == 1
    end

    expect { described_class.perform_now(message.id) }.not_to raise_error
    expect(call_count).to eq(2)
  end
end
