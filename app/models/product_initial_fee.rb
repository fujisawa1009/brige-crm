# 商材の初期費用テンプレート（04 R2タスク3・Laravel移行元 ProductInitialFee.php）。
# == Schema Information
#
# Table name: product_initial_fees
#
#  id            :uuid             not null, primary key
#  amount        :integer          not null
#  is_active     :boolean          default(TRUE), not null
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
#  index_product_initial_fees_on_is_active                  (is_active)
#  index_product_initial_fees_on_product_id_and_sort_order  (product_id,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (product_id => products.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class ProductInitialFee < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :product

  has_many :orders, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
end
