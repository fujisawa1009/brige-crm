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
  # 循環参照・グループ越境バグ修正: 自己参照/祖先方向の循環と、親子で所属グループが食い違う
  # 状態を保存させない（フォームからの不正なparent_id指定・自己申告depthの両方を防ぐ）。
  validate :parent_must_be_same_option_group
  validate :parent_must_not_create_cycle

  # depthは常にparentから導出する（フォーム入力値やparams由来のdepthは無視する）。
  before_validation :assign_depth_from_parent

  scope :active, -> { where(is_active: true) }
  scope :roots, -> { where(parent_id: nil) }

  private

  def assign_depth_from_parent
    self.depth = parent ? parent.depth + 1 : 0
  end

  def parent_must_be_same_option_group
    return if parent.nil?
    return if parent.option_group_id == option_group_id

    errors.add(:parent_id, "所属グループが異なる選択肢は親にできません")
  end

  # 親をたどって自分自身に戻る経路（自己参照を含む）が無いことを検証する。
  def parent_must_not_create_cycle
    return if parent_id.blank?

    visited = Set.new
    ancestor = parent
    while ancestor
      if ancestor.id == id || visited.include?(ancestor.id)
        errors.add(:parent_id, "自分自身または子孫を親にはできません（循環参照）")
        return
      end
      visited << ancestor.id
      ancestor = ancestor.parent
    end
  end
end
