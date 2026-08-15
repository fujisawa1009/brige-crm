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
FactoryBot.define do
  factory :option_group do
    sequence(:key) { |n| "group_key_#{n}" }
    sequence(:label) { |n| "選択肢グループ#{n}" }
    is_active { true }
  end
end
