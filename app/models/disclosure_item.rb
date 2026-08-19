# 重説項目（04 R5-13・contract-confirmation-docs.md §3-1）。DisclosureItemSetに属する。
# == Schema Information
#
# Table name: disclosure_items
#
#  id                     :uuid             not null, primary key
#  body                   :text             not null
#  is_required            :boolean          default(TRUE), not null
#  sort_order             :integer          default(0), not null
#  title                  :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  disclosure_item_set_id :uuid             not null
#
# Indexes
#
#  index_disclosure_items_on_disclosure_item_set_id  (disclosure_item_set_id)
#
# Foreign Keys
#
#  fk_rails_...  (disclosure_item_set_id => disclosure_item_sets.id)
#
class DisclosureItem < ApplicationRecord
  belongs_to :disclosure_item_set

  has_many :disclosure_check_items, dependent: :restrict_with_error

  validates :title, presence: true, length: { maximum: 255 }
  validates :body, presence: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
