# == Schema Information
#
# Table name: agencies
#
#  id                          :uuid             not null, primary key
#  agency_code                 :string           not null
#  contact_person              :string
#  csv_download_visible        :boolean
#  electronic_contract_enabled :boolean
#  email_1                     :string
#  email_2                     :string
#  email_3                     :string
#  email_4                     :string
#  email_5                     :string
#  name                        :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  agency_group_id             :uuid             not null
#  created_by_id               :uuid
#  updated_by_id               :uuid
#
# Indexes
#
#  index_agencies_on_agency_code      (agency_code) UNIQUE
#  index_agencies_on_agency_group_id  (agency_group_id)
#  index_agencies_on_name             (name)
#
# Foreign Keys
#
#  fk_rails_...  (agency_group_id => agency_groups.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :agency do
    association :agency_group
    sequence(:name) { |n| "テスト代理店#{n}" }
    sequence(:agency_code) { |n| "AGY#{n}" }
  end
end
