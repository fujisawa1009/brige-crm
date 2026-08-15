# == Schema Information
#
# Table name: products
#
#  id            :uuid             not null, primary key
#  code          :string(20)       not null
#  description   :text
#  is_active     :boolean          default(TRUE), not null
#  name          :string(100)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_products_on_code       (code) UNIQUE
#  index_products_on_is_active  (is_active)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "商材#{n}" }
    sequence(:code) { |n| "PRD#{n}" }
    is_active { true }
  end
end
