require "rails_helper"

# 04 R5-1: OrderStatus/CustomerStatusと同じSystemManagedStatus保護。
# == Schema Information
#
# Table name: contract_statuses
#
#  id            :uuid             not null, primary key
#  code          :string           not null
#  is_active     :boolean          default(TRUE), not null
#  is_system     :boolean          default(FALSE), not null
#  label         :string           not null
#  sort_order    :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_contract_statuses_on_code                      (code) UNIQUE
#  index_contract_statuses_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe ContractStatus, type: :model do
  it "is_system=falseの行は削除できる" do
    status = create(:contract_status, is_system: false)
    expect(status.destroy).to be_truthy
  end

  it "is_system=trueの行は削除できない" do
    status = create(:contract_status, is_system: true)
    expect(status.destroy).to be_falsey
    expect(status.errors[:base]).to be_present
    expect(ContractStatus.exists?(status.id)).to eq(true)
  end

  it "is_system=trueの行はcodeを変更できない" do
    status = create(:contract_status, is_system: true)
    status.code = "changed"
    expect(status).not_to be_valid
    expect(status.errors[:code]).to be_present
  end
end
