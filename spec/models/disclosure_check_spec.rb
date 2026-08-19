require "rails_helper"

# R5-13（contract-confirmation-docs.md §3-1）: 重説チェックはQ-4決定により
# 「必須項目が未チェックのままresult=completedにはできない」ことをモデル側でも担保する。
# == Schema Information
#
# Table name: disclosure_checks
#
#  id                     :uuid             not null, primary key
#  method                 :string           default("web_check"), not null
#  performed_at           :datetime         not null
#  performed_by_type      :string           not null
#  result                 :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  disclosure_item_set_id :uuid             not null
#  order_id               :uuid             not null
#  performed_by_id        :uuid             not null
#
# Indexes
#
#  idx_on_performed_by_type_performed_by_id_6fec7c8419  (performed_by_type,performed_by_id)
#  index_disclosure_checks_on_order_id                  (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (disclosure_item_set_id => disclosure_item_sets.id)
#  fk_rails_...  (order_id => orders.id)
#
RSpec.describe DisclosureCheck, type: :model, seed_status_catalog: true do
  let(:item_set) { create(:disclosure_item_set) }
  let!(:required_item) { create(:disclosure_item, disclosure_item_set: item_set, is_required: true) }
  let!(:optional_item) { create(:disclosure_item, disclosure_item_set: item_set, is_required: false) }
  let(:order) { create(:order) }
  let(:customer) { create(:customer) }

  it "必須項目を全てチェックしていればresult=completedで保存できる" do
    check = build(:disclosure_check, order: order, disclosure_item_set: item_set, performed_by: customer,
                                      result: DisclosureCheck::RESULT_COMPLETED)
    check.disclosure_check_items.build(disclosure_item: required_item, checked: true)
    check.disclosure_check_items.build(disclosure_item: optional_item, checked: false)

    expect(check).to be_valid
  end

  it "必須項目が未チェックならresult=completedでは保存できない" do
    check = build(:disclosure_check, order: order, disclosure_item_set: item_set, performed_by: customer,
                                      result: DisclosureCheck::RESULT_COMPLETED)
    check.disclosure_check_items.build(disclosure_item: required_item, checked: false)

    expect(check).not_to be_valid
    expect(check.errors[:base]).to be_present
  end

  it "result=incompleteなら必須項目が未チェックでも保存できる" do
    check = build(:disclosure_check, order: order, disclosure_item_set: item_set, performed_by: customer,
                                      result: DisclosureCheck::RESULT_INCOMPLETE)
    check.disclosure_check_items.build(disclosure_item: required_item, checked: false)

    expect(check).to be_valid
  end

  it "method/resultは定義された値以外を許容しない" do
    check = build(:disclosure_check, order: order, disclosure_item_set: item_set, performed_by: customer,
                                      method: "phone_check")
    expect(check).not_to be_valid
    expect(check.errors[:method]).to be_present
  end
end
