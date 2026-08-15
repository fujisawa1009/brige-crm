require "rails_helper"

# 04 R2タスク4: is_system=trueの行はcode変更・削除不可（SystemManagedStatus concern）。
# == Schema Information
#
# Table name: customer_statuses
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
#  index_customer_statuses_on_code                      (code) UNIQUE
#  index_customer_statuses_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe CustomerStatus, type: :model do
  it "is_system=falseの行は削除できる" do
    status = create(:customer_status, is_system: false)
    expect(status.destroy).to be_truthy
  end

  it "is_system=trueの行は削除できない" do
    status = create(:customer_status, is_system: true)
    expect(status.destroy).to be_falsey
    expect(status.errors[:base]).to be_present
    expect(CustomerStatus.exists?(status.id)).to eq(true)
  end

  it "is_system=trueの行はcodeを変更できない" do
    status = create(:customer_status, is_system: true)
    status.code = "changed"
    expect(status).not_to be_valid
    expect(status.errors[:code]).to be_present
  end

  it "is_system=trueでもlabelは変更できる" do
    status = create(:customer_status, is_system: true)
    status.label = "変更後ラベル"
    expect(status).to be_valid
  end
end
