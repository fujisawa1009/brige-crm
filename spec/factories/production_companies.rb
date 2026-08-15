# == Schema Information
#
# Table name: production_companies
#
#  id            :uuid             not null, primary key
#  contact_name  :string(50)
#  email         :string(255)
#  is_active     :boolean          default(TRUE), not null
#  name          :string(100)      not null
#  notes         :text
#  phone         :string(20)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_production_companies_on_is_active  (is_active)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :production_company do
    sequence(:name) { |n| "制作会社#{n}" }
    is_active { true }
  end
end
