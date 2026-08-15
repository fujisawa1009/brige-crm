# 契約条件バージョン（04 R1・Column.md §6）。effective_until = NULL が現行バージョン。
#
# 申し送り（T-3・03§5）: Laravel是正方針は「contract_condition_id を受注（Order）側に持たせる」だが、
# OrderはR2でしか作られないため、R1では Agency 1─* ContractCondition の単体CRUDのみを実装する。
# R2でOrderモデルを作る際に orders.contract_condition_id（FK, not null, 受注時点のバージョンを固定
# 参照）を追加すること（db/migrate/20260815130004_create_contract_conditions.rb コメントも参照）。
# == Schema Information
#
# Table name: contract_conditions
#
#  id              :uuid             not null, primary key
#  effective_from  :date             not null
#  effective_until :date
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  agency_id       :uuid             not null
#  created_by_id   :uuid
#  updated_by_id   :uuid
#
# Indexes
#
#  index_contract_conditions_on_agency_id        (agency_id)
#  index_contract_conditions_on_effective_until  (effective_until)
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => cascade
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class ContractCondition < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :agency

  # 04 R2: T-3是正どおりOrder側がcontract_condition_idを保持する（このモデルからの逆参照）。
  has_many :orders, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 255 }
  validates :effective_from, presence: true
  validate :effective_until_after_effective_from

  scope :current, -> { where(effective_until: nil) }

  def current?
    effective_until.nil?
  end

  private

  def effective_until_after_effective_from
    return if effective_from.blank? || effective_until.blank?
    return if effective_until >= effective_from

    errors.add(:effective_until, "は適用開始日以降の日付にしてください")
  end
end
