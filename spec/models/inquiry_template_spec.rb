require "rails_helper"

# R6-4: 問い合わせ返信テンプレート（FAQ 12カテゴリ×本文）のマスタ。
# == Schema Information
#
# Table name: inquiry_templates
#
#  id            :uuid             not null, primary key
#  body          :text             not null
#  category      :string           not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_inquiry_templates_on_category  (category)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe InquiryTemplate, type: :model do
  it "category/name/bodyが揃っていれば有効" do
    template = build(:inquiry_template)
    expect(template).to be_valid
  end

  it "categoryが空だと無効" do
    template = build(:inquiry_template, category: nil)
    expect(template).not_to be_valid
    expect(template.errors[:category]).to be_present
  end

  it "CATEGORIESに無い値だと無効（FAQ12カテゴリの揺れ防止）" do
    template = build(:inquiry_template, category: "存在しないカテゴリ")
    expect(template).not_to be_valid
    expect(template.errors[:category]).to be_present
  end

  it "nameが空だと無効" do
    template = build(:inquiry_template, name: nil)
    expect(template).not_to be_valid
  end

  it "bodyが空だと無効" do
    template = build(:inquiry_template, body: nil)
    expect(template).not_to be_valid
  end
end
