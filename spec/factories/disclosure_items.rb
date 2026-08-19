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
FactoryBot.define do
  factory :disclosure_item do
    association :disclosure_item_set
    sequence(:sort_order) { |n| n }
    sequence(:title) { |n| "重説項目#{n}" }
    body { "本文サンプル" }
    is_required { true }
  end
end
