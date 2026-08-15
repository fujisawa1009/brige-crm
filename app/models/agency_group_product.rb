# 販売許可（Product×AgencyGroup中間。04 R2タスク3）。
# == Schema Information
#
# Table name: agency_group_products
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  agency_group_id :uuid             not null
#  product_id      :uuid             not null
#
# Indexes
#
#  index_agency_group_products_on_group_and_product  (agency_group_id,product_id) UNIQUE
#  index_agency_group_products_on_product_id         (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (agency_group_id => agency_groups.id) ON DELETE => cascade
#  fk_rails_...  (product_id => products.id) ON DELETE => cascade
#
class AgencyGroupProduct < ApplicationRecord
  belongs_to :agency_group
  belongs_to :product

  validates :agency_group_id, uniqueness: { scope: :product_id }
end
