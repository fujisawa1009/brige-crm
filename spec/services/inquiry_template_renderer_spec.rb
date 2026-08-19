require "rails_helper"

# R6-4: legacy-research/13-faq-templates.md §2の差し込み変数展開。
RSpec.describe InquiryTemplateRenderer, seed_status_catalog: true do
  let(:customer) { create(:customer, name: "株式会社テスト商事") }
  let(:order) { create(:order, customer: customer, agency: customer.agency, order_number: "ORD202600001") }
  let(:inquiry) { create(:inquiry, order: order) }

  it "%{customer_name}・%{order_number}・%{inquiry_number}を実データへ展開する" do
    template = build(:inquiry_template,
      body: "%{customer_name}様（案件番号: %{order_number} / 問い合わせ番号: %{inquiry_number}）")

    rendered = described_class.render(template, inquiry)

    expect(rendered).to eq("株式会社テスト商事様（案件番号: ORD202600001 / 問い合わせ番号: #{inquiry.inquiry_number}）")
  end

  it "対応するStoreが無い案件では%{store_name}を空文字へフォールバックする（例外にしない）" do
    template = build(:inquiry_template, body: "店舗名: [%{store_name}]")

    rendered = described_class.render(template, inquiry)

    expect(rendered).to eq("店舗名: []")
  end

  it "Storeが存在すれば%{store_name}を展開する" do
    store = create(:store, customer: customer, store_name: "渋谷店")
    order.update!(store: store)
    template = build(:inquiry_template, body: "店舗名: %{store_name}")

    rendered = described_class.render(template, inquiry)

    expect(rendered).to eq("店舗名: 渋谷店")
  end

  it "未定義のプレースホルダーはそのまま残す（テンプレート入力ミスで例外にしない）" do
    template = build(:inquiry_template, body: "未知の変数: %{unknown_variable}")

    rendered = described_class.render(template, inquiry)

    expect(rendered).to eq("未知の変数: %{unknown_variable}")
  end
end
