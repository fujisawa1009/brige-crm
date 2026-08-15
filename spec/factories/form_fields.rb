# == Schema Information
#
# Table name: form_fields
#
#  id                :uuid             not null, primary key
#  editable_by_tier  :string           default(["sales_representative"]), not null, is an Array
#  field_key         :string           not null
#  field_type        :string           not null
#  input_options     :jsonb            not null
#  label             :string           not null
#  lock_after_status :string
#  required          :boolean          default(FALSE), not null
#  sort_order        :integer          default(0), not null
#  target_column     :string
#  target_table      :string           not null
#  validation_rules  :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  created_by_id     :uuid
#  form_step_id      :uuid             not null
#  updated_by_id     :uuid
#
# Indexes
#
#  index_form_fields_on_editable_by_tier            (editable_by_tier) USING gin
#  index_form_fields_on_form_step_id_and_field_key  (form_step_id,field_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (form_step_id => form_steps.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :form_field do
    association :form_step
    sequence(:field_key) { |n| "field_#{n}" }
    sequence(:label) { |n| "項目#{n}" }
    field_type { "text" }
    target_table { "customer" }
    target_column { "name" }
    required { false }
    sort_order { 0 }
    editable_by_tier { [ "sales_representative" ] }
  end
end
