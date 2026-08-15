# == Schema Information
#
# Table name: plans
#
#  id            :uuid             not null, primary key
#  code          :string(20)
#  is_active     :boolean          default(TRUE), not null
#  monthly_fee   :integer
#  name          :string(100)      not null
#  sort_order    :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  product_id    :uuid             not null
#  updated_by_id :uuid
#
# Indexes
#
#  index_plans_on_is_active   (is_active)
#  index_plans_on_product_id  (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (product_id => products.id) ON DELETE => restrict
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :plan do
    association :product
    sequence(:name) { |n| "プラン#{n}" }
    monthly_fee { 5000 }
    is_active { true }
  end
end
