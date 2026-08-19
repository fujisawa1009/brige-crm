# == Schema Information
#
# Table name: order_statuses
#
#  id            :uuid             not null, primary key
#  code          :string           not null
#  is_active     :boolean          default(TRUE), not null
#  is_completed  :boolean          default(FALSE), not null
#  is_system     :boolean          default(FALSE), not null
#  label         :string           not null
#  sort_order    :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_order_statuses_on_code                      (code) UNIQUE
#  index_order_statuses_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :order_status do
    sequence(:code) { |n| "order_status_#{n}" }
    sequence(:label) { |n| "案件ステータス#{n}" }
    is_active { true }
    is_system { false }
  end
end
