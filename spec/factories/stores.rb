# == Schema Information
#
# Table name: stores
#
#  id               :uuid             not null, primary key
#  address_detail   :string(200)
#  business_hours_1 :string(50)
#  business_hours_2 :string(50)
#  city             :string(50)
#  fax_number       :string(20)
#  is_active        :boolean          default(TRUE), not null
#  phone_number     :string(20)
#  postal_code      :string(8)
#  prefecture       :string(20)
#  regular_holiday  :string(100)
#  store_code       :string(20)
#  store_name       :string(255)      not null
#  store_name_kana  :string(255)
#  town             :string(100)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :uuid
#  customer_id      :uuid             not null
#  updated_by_id    :uuid
#
# Indexes
#
#  index_stores_on_customer_id  (customer_id)
#  index_stores_on_is_active    (is_active)
#  index_stores_on_store_code   (store_code)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (customer_id => customers.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :store do
    association :customer
    sequence(:store_name) { |n| "テスト店舗#{n}" }
    is_active { true }
  end
end
