# == Schema Information
#
# Table name: order_options
#
#  id                :uuid             not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  order_id          :uuid             not null
#  product_option_id :uuid             not null
#
# Indexes
#
#  index_order_options_on_order_id_and_product_option_id  (order_id,product_option_id) UNIQUE
#  index_order_options_on_product_option_id               (product_option_id)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#  fk_rails_...  (product_option_id => product_options.id) ON DELETE => restrict
#
FactoryBot.define do
  factory :order_option do
    association :order
    association :product_option
  end
end
