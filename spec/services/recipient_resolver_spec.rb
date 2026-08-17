require "rails_helper"

# 04 R4タスク1・2: RecipientResolver#expand_for_send（Laravel expandForSend 移植）の展開検証。
# 5タイプ（Agency/SalesRepresentative/Customer/User/RecipientGroup）の展開と、メールなし宛先の
# 除外を確認する。メール送信ジョブ（InquiryMessageMailJob）が正しい宛先集合を得られることの土台。
RSpec.describe RecipientResolver, type: :service, seed_status_catalog: true do
  describe ".expand_for_send" do
    it "Agency は複数メール列(email_1..5)を代表+ccとして1エントリに展開する" do
      agency = create(:agency, email_1: "a1@example.com", email_3: "a3@example.com")

      result = described_class.expand_for_send([ { type: "Agency", id: agency.id } ])

      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq("Agency")
      expect(result.first[:emails]).to eq([ "a1@example.com", "a3@example.com" ])
    end

    it "SalesRepresentative は自身のメールで1エントリに展開する" do
      agency = create(:agency)
      rep = create(:sales_representative, agency: agency, email: "rep@example.com")

      result = described_class.expand_for_send([ { type: "SalesRepresentative", id: rep.id } ])

      expect(result.size).to eq(1)
      expect(result.first).to include(type: "SalesRepresentative", emails: [ "rep@example.com" ])
    end

    it "Customer は自身のメールで1エントリに展開する" do
      customer = create(:customer, email: "cust@example.com")

      result = described_class.expand_for_send([ { type: "Customer", id: customer.id } ])

      expect(result.first).to include(type: "Customer", emails: [ "cust@example.com" ])
    end

    it "User は自身のメールで1エントリに展開する" do
      user = create(:user, email: "user@example.com")

      result = described_class.expand_for_send([ { type: "User", id: user.id } ])

      expect(result.first).to include(type: "User", emails: [ "user@example.com" ])
    end

    it "RecipientGroup はメンバー(User/ProductionCompany)を各1エントリへ展開する" do
      group = create(:recipient_group)
      user = create(:user, email: "member@example.com")
      company = create(:production_company, email: "company@example.com")
      create(:recipient_group_member, recipient_group: group, recipient: user)
      create(:recipient_group_member, recipient_group: group, recipient: company)

      result = described_class.expand_for_send([ { type: "RecipientGroup", id: group.id } ])

      expect(result.map { |e| e[:type] }).to contain_exactly("User", "ProductionCompany")
      expect(result.flat_map { |e| e[:emails] }).to contain_exactly("member@example.com", "company@example.com")
    end

    it "メールを持たない宛先は除外する（送信不能な宛先で集計を汚さない）" do
      agency_no_mail = create(:agency) # email列すべてnil
      customer_with_mail = create(:customer, email: "ok@example.com")

      result = described_class.expand_for_send([
        { type: "Agency", id: agency_no_mail.id },
        { type: "Customer", id: customer_with_mail.id }
      ])

      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq("Customer")
    end

    it "RecipientGroup 内のメールなしメンバーは除外する" do
      group = create(:recipient_group)
      user_with_mail = create(:user, email: "with@example.com")
      company_no_mail = create(:production_company, email: nil)
      create(:recipient_group_member, recipient_group: group, recipient: user_with_mail)
      create(:recipient_group_member, recipient_group: group, recipient: company_no_mail)

      result = described_class.expand_for_send([ { type: "RecipientGroup", id: group.id } ])

      expect(result.map { |e| e[:type] }).to eq([ "User" ])
    end

    it "存在しないID・未知のtypeは空配列になる" do
      expect(described_class.expand_for_send([ { type: "Agency", id: SecureRandom.uuid } ])).to eq([])
      expect(described_class.expand_for_send([ { type: "Unknown", id: SecureRandom.uuid } ])).to eq([])
    end
  end

  describe ".route_for" do
    it "category×status_codeに割り当てられたrecipient_groupを返す" do
      group = create(:recipient_group)
      other = create(:recipient_group)
      create(:inquiry_recipient_route, recipient_group: group,
                                       category: Inquiry::CATEGORY_AFTER, status_code: "未対応")
      create(:inquiry_recipient_route, recipient_group: other,
                                       category: Inquiry::CATEGORY_AFTER, status_code: "対応中")

      result = described_class.route_for(category: Inquiry::CATEGORY_AFTER, status_code: "未対応")

      expect(result).to contain_exactly(group)
    end
  end

  describe "#recipients_for_inquiry" do
    it "案件経由の宛先（メール有り）＋ステータスのルーティンググループをマージする" do
      agency = create(:agency, email_1: "agency@example.com")
      customer = create(:customer, agency: agency, email: "cust@example.com")
      order = create(:order, agency: agency, customer: customer)
      inquiry = create(:inquiry, order: order, category: Inquiry::CATEGORY_AFTER)

      group = create(:recipient_group)
      create(:inquiry_recipient_route, recipient_group: group,
                                       category: Inquiry::CATEGORY_AFTER, status_code: inquiry.status)

      result = described_class.recipients_for_inquiry(inquiry)

      expect(result).to include({ type: "Agency", id: agency.id })
      expect(result).to include({ type: "Customer", id: customer.id })
      expect(result).to include({ type: "RecipientGroup", id: group.id })
    end
  end
end
