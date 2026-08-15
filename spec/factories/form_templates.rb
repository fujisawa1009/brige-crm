# == Schema Information
#
# Table name: form_templates
#
#  id            :uuid             not null, primary key
#  is_active     :boolean          default(TRUE), not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  product_id    :uuid             not null
#  updated_by_id :uuid
#
# Indexes
#
#  index_form_templates_on_product_id  (product_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (product_id => products.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :form_template do
    association :product
    sequence(:name) { |n| "申込フォーム#{n}" }
    is_active { true }
  end
end
