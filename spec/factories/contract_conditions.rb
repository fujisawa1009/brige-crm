# == Schema Information
#
# Table name: contract_conditions
#
#  id              :uuid             not null, primary key
#  effective_from  :date             not null
#  effective_until :date
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  agency_id       :uuid             not null
#  created_by_id   :uuid
#  updated_by_id   :uuid
#
# Indexes
#
#  index_contract_conditions_on_agency_id        (agency_id)
#  index_contract_conditions_on_effective_until  (effective_until)
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => cascade
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :contract_condition do
    association :agency
    sequence(:name) { |n| "契約条件#{n}" }
    effective_from { 1.year.ago.to_date }
    effective_until { nil }
  end
end
