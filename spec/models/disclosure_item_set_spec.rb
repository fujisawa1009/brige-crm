require "rails_helper"

# == Schema Information
#
# Table name: disclosure_item_sets
#
#  id             :uuid             not null, primary key
#  effective_from :date             not null
#  version        :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  created_by_id  :uuid
#  updated_by_id  :uuid
#
# Indexes
#
#  index_disclosure_item_sets_on_version  (version) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe DisclosureItemSet, type: :model do
  it "versionは一意でなければならない" do
    create(:disclosure_item_set, version: 1)
    duplicate = build(:disclosure_item_set, version: 1)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:version]).to be_present
  end

  it "ネスト属性で項目をまとめて作成できる" do
    item_set = DisclosureItemSet.create!(
      version: 1, effective_from: Date.current,
      disclosure_items_attributes: [
        { sort_order: 1, title: "第1項目", body: "本文1", is_required: true },
        { sort_order: 2, title: "第2項目", body: "本文2", is_required: false }
      ]
    )

    expect(item_set.disclosure_items.count).to eq(2)
  end

  it "紐づくdisclosure_itemsが存在する場合は削除できない" do
    item_set = create(:disclosure_item_set)
    create(:disclosure_item, disclosure_item_set: item_set)

    expect(item_set.destroy).to be_falsey
    expect(item_set.errors[:base]).to be_present
    expect(DisclosureItemSet.exists?(item_set.id)).to eq(true)
  end
end
