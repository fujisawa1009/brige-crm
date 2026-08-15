require "rails_helper"

# 04 R2タスク3・8: 販売許可（AgencyProduct/AgencyGroupProduct）とProduct.sellable_byを検証する。
# == Schema Information
#
# Table name: products
#
#  id            :uuid             not null, primary key
#  code          :string(20)       not null
#  description   :text
#  is_active     :boolean          default(TRUE), not null
#  name          :string(100)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_products_on_code       (code) UNIQUE
#  index_products_on_is_active  (is_active)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe Product, type: :model do
  describe ".sellable_by" do
    let!(:allowed_product) { create(:product) }
    let!(:group_allowed_product) { create(:product) }
    let!(:not_allowed_product) { create(:product) }
    let!(:agency_group) { create(:agency_group) }
    let!(:agency) { create(:agency, agency_group: agency_group) }

    before do
      AgencyProduct.create!(agency: agency, product: allowed_product)
      AgencyGroupProduct.create!(agency_group: agency_group, product: group_allowed_product)
    end

    it "代理店に直接許可された商材を含む" do
      expect(Product.sellable_by(agency)).to include(allowed_product)
    end

    it "所属代理店グループに許可された商材を含む" do
      expect(Product.sellable_by(agency)).to include(group_allowed_product)
    end

    it "許可されていない商材は含まない" do
      expect(Product.sellable_by(agency)).not_to include(not_allowed_product)
    end
  end
end
