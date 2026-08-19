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
FactoryBot.define do
  factory :disclosure_check_item do
    association :disclosure_check
    association :disclosure_item
    checked { true }
  end
end
