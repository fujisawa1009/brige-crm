# 重説項目セット（04 R5-13・contract-confirmation-docs.md §3-1）。版管理されたマスタ。
# 項目が変わっても disclosure_checks は実施時点の版を固定参照するため、過去の証跡が壊れない。
# == Schema Information
#
# Table name: disclosure_item_sets
#
#  id             :uuid             not null, primary key
#  effective_from :date             not null
#  version        :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  created_by_id  :uuid
#  updated_by_id  :uuid
#
# Indexes
#
#  index_disclosure_item_sets_on_version  (version) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class DisclosureItemSet < ApplicationRecord
  include TracksUser

  has_many :disclosure_items, -> { order(:sort_order) }, dependent: :restrict_with_error
  has_many :disclosure_checks, dependent: :restrict_with_error

  accepts_nested_attributes_for :disclosure_items, allow_destroy: true, reject_if: :all_blank

  validates :version, presence: true, uniqueness: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :effective_from, presence: true
end
