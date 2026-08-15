# 選択肢グループ（業種・支払方法等のカテゴリ。04 R2タスク4・Column.md移行元はLaravel option_groups）。
# key はコード側から参照する固定キーのため一意・必須。
# == Schema Information
#
# Table name: option_groups
#
#  id            :uuid             not null, primary key
#  description   :text
#  is_active     :boolean          default(TRUE), not null
#  key           :string           not null
#  label         :string           not null
#  sort_order    :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_option_groups_on_is_active   (is_active)
#  index_option_groups_on_key         (key) UNIQUE
#  index_option_groups_on_sort_order  (sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class OptionGroup < ApplicationRecord
  include TracksUser
  include Auditable

  has_many :option_values, dependent: :destroy

  validates :key, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :label, presence: true, length: { maximum: 255 }

  scope :active, -> { where(is_active: true) }

  # ルート選択肢のみ（parent_idなし）
  def root_values
    option_values.where(parent_id: nil).order(:sort_order)
  end
end
