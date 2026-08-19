# == Schema Information
#
# Table name: disclosure_checks
#
#  id                     :uuid             not null, primary key
#  method                 :string           default("web_check"), not null
#  performed_at           :datetime         not null
#  performed_by_type      :string           not null
#  result                 :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  disclosure_item_set_id :uuid             not null
#  order_id               :uuid             not null
#  performed_by_id        :uuid             not null
#
# Indexes
#
#  idx_on_performed_by_type_performed_by_id_6fec7c8419  (performed_by_type,performed_by_id)
#  index_disclosure_checks_on_order_id                  (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (disclosure_item_set_id => disclosure_item_sets.id)
#  fk_rails_...  (order_id => orders.id)
#
FactoryBot.define do
  factory :disclosure_check do
    association :order
    association :disclosure_item_set
    association :performed_by, factory: :customer
    performed_at { Time.current }
    # "method"はKernel#methodと衝突しFactoryBotのブロックDSLが使えないため、add_attributeで明示する。
    add_attribute(:method) { DisclosureCheck::METHOD_WEB_CHECK }
    result { DisclosureCheck::RESULT_COMPLETED }
  end
end
