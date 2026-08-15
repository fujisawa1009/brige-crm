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
FactoryBot.define do
  factory :option_value do
    association :option_group
    sequence(:value) { |n| "value_#{n}" }
    sequence(:label) { |n| "選択肢#{n}" }
    is_active { true }
  end
end
