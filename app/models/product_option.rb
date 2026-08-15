# 商材のオプション（04 R2タスク3・Laravel移行元 ProductOption.php）。
# Order側の選択オプション（jasmin_order_options中間テーブル）はR3（申込トランザクション）実装時に
# 追加する。R2時点ではオプションマスタ自体の管理のみをスコープとする。
# == Schema Information
#
# Table name: product_options
#
#  id            :uuid             not null, primary key
#  description   :text
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
#  index_product_options_on_is_active                  (is_active)
#  index_product_options_on_product_id_and_sort_order  (product_id,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (product_id => products.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class ProductOption < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :product

  validates :name, presence: true, length: { maximum: 100 }
  validates :monthly_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
end
