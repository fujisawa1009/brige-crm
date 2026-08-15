# 選択肢値（OptionGroupに属する。parent_idの自己参照でツリー化。04 R2タスク4）。
# 無効化(is_active=false)は論理削除として扱う。既存の契約・受注データが旧ラベルを
# スナップショット参照している可能性があるため、レコード自体は削除しない運用（Laravel踏襲）。
# == Schema Information
#
# Table name: option_values
#
#  id              :uuid             not null, primary key
#  depth           :integer          default(0), not null
#  is_active       :boolean          default(TRUE), not null
#  label           :string           not null
#  sort_order      :integer          default(0), not null
#  value           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :uuid
#  option_group_id :uuid             not null
#  parent_id       :uuid
#  updated_by_id   :uuid
#
# Indexes
#
#  index_option_values_on_is_active                  (is_active)
#  index_option_values_on_option_group_id            (option_group_id)
#  index_option_values_on_option_group_id_and_value  (option_group_id,value) UNIQUE
#  index_option_values_on_parent_id                  (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (option_group_id => option_groups.id) ON DELETE => cascade
#  fk_rails_...  (parent_id => option_values.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class OptionValue < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :option_group
  belongs_to :parent, class_name: "OptionValue", optional: true
  has_many :children, class_name: "OptionValue", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  validates :value, presence: true, uniqueness: { scope: :option_group_id }, length: { maximum: 255 }
  validates :label, presence: true, length: { maximum: 255 }

  scope :active, -> { where(is_active: true) }
  scope :roots, -> { where(parent_id: nil) }
end
