# == Schema Information
#
# Table name: agency_groups
#
#  id                       :uuid             not null, primary key
#  bridge_plan_display_type :string
#  contact_email            :string
#  csv_download_visible     :boolean
#  group_code               :string           not null
#  name                     :string           not null
#  service_type             :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  created_by_id            :uuid
#  updated_by_id            :uuid
#
# Indexes
#
#  index_agency_groups_on_group_code  (group_code) UNIQUE
#  index_agency_groups_on_name        (name)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :agency_group do
    sequence(:name) { |n| "テストグループ#{n}" }
    service_type { "BridgePlus" }
    sequence(:group_code) { |n| "GRP#{n}" }
  end
end
