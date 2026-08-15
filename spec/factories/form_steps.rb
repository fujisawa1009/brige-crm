# == Schema Information
#
# Table name: form_steps
#
#  id               :uuid             not null, primary key
#  name             :string           not null
#  step_number      :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :uuid
#  form_template_id :uuid             not null
#  updated_by_id    :uuid
#
# Indexes
#
#  index_form_steps_on_form_template_id_and_step_number  (form_template_id,step_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (form_template_id => form_templates.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :form_step do
    association :form_template
    sequence(:step_number) { |n| n }
    sequence(:name) { |n| "ステップ#{n}" }
  end
end
