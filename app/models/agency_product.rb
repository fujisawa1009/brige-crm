# 販売許可（Product×Agency中間。04 R1で先送り→R2でProductと同時実装。04 R2タスク3）。
# == Schema Information
#
# Table name: agency_products
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  agency_id  :uuid             not null
#  product_id :uuid             not null
#
# Indexes
#
#  index_agency_products_on_agency_id_and_product_id  (agency_id,product_id) UNIQUE
#  index_agency_products_on_product_id                (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => cascade
#  fk_rails_...  (product_id => products.id) ON DELETE => cascade
#
class AgencyProduct < ApplicationRecord
  belongs_to :agency
  belongs_to :product

  validates :agency_id, uniqueness: { scope: :product_id }
end
