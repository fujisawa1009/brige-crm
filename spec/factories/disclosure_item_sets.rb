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
FactoryBot.define do
  factory :disclosure_item_set do
    sequence(:version) { |n| n }
    effective_from { Date.current }
  end
end
