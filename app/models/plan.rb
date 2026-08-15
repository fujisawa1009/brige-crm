# プラン（商材配下。月額料金等。04 R2タスク3・Laravel移行元 Plan.php）。
# == Schema Information
#
# Table name: plans
#
#  id            :uuid             not null, primary key
#  code          :string(20)
#  is_active     :boolean          default(TRUE), not null
#  monthly_fee   :integer
#  name          :string(100)      not null
#  sort_order    :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  product_id    :uuid             not null
#  updated_by_id :uuid
#
# Indexes
#
#  index_plans_on_is_active   (is_active)
#  index_plans_on_product_id  (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (product_id => products.id) ON DELETE => restrict
#  fk_rails_...  (updated_by_id => users.id)
#
class Plan < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :product

  has_many :orders, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, length: { maximum: 20 }
  validates :monthly_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
end
