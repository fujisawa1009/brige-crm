require "rails_helper"

# R5-5b（master-data-design-policy.md §5-3）: OrderStatus/CustomerStatusと同じSystemManagedStatus保護。
# == Schema Information
#
# Table name: payment_methods
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
#  index_payment_methods_on_code                      (code) UNIQUE
#  index_payment_methods_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe PaymentMethod, type: :model do
  it "is_system=falseの行は削除できる" do
    method = create(:payment_method, is_system: false)
    expect(method.destroy).to be_truthy
  end

  it "is_system=trueの行は削除できない" do
    method = create(:payment_method, is_system: true)
    expect(method.destroy).to be_falsey
    expect(method.errors[:base]).to be_present
    expect(PaymentMethod.exists?(method.id)).to eq(true)
  end

  it "is_system=trueの行はcodeを変更できない" do
    method = create(:payment_method, is_system: true)
    method.code = "changed"
    expect(method).not_to be_valid
    expect(method.errors[:code]).to be_present
  end
end
