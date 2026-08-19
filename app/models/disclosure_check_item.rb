# 重説チェックの項目ごとの結果明細（04 R5-13・contract-confirmation-docs.md §3-1）。
# == Schema Information
#
# Table name: disclosure_check_items
#
#  id                  :uuid             not null, primary key
#  checked             :boolean          default(FALSE), not null
#  checked_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  disclosure_check_id :uuid             not null
#  disclosure_item_id  :uuid             not null
#
# Indexes
#
#  index_disclosure_check_items_on_check_and_item       (disclosure_check_id,disclosure_item_id) UNIQUE
#  index_disclosure_check_items_on_disclosure_check_id  (disclosure_check_id)
#
# Foreign Keys
#
#  fk_rails_...  (disclosure_check_id => disclosure_checks.id)
#  fk_rails_...  (disclosure_item_id => disclosure_items.id)
#
class DisclosureCheckItem < ApplicationRecord
  belongs_to :disclosure_check
  belongs_to :disclosure_item

  validates :disclosure_item_id, uniqueness: { scope: :disclosure_check_id }

  before_validation :assign_checked_at

  private

  def assign_checked_at
    self.checked_at = Time.current if checked? && checked_at.blank?
  end
end
