# == Schema Information
#
# Table name: recipient_groups
#
#  id            :uuid             not null, primary key
#  description   :text
#  is_active     :boolean          default(TRUE), not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_recipient_groups_on_is_active  (is_active)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :recipient_group do
    sequence(:name) { |n| "宛先グループ#{n}" }
    is_active { true }
  end
end
