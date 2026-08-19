# 顧客のstatus初期値（Customer#assign_default_status）はcustomer_statusesテーブルに
# CustomerStatus::CODE_APPLIED行が存在することを前提とする（app/models/customer.rb参照）。
# このfactoryを使うspecは :seed_status_catalog タグ（spec/support/status_seed_helper.rb）で
# StatusSeeder.callを先に実行しておくこと。
# == Schema Information
#
# Table name: customers
#
#  id                       :uuid             not null, primary key
#  address_detail           :string(200)
#  agency_customer_code     :string(50)
#  applicant_type           :string(20)
#  applied_at               :date
#  appointer_code           :string(20)
#  appointer_name           :string(50)
#  city                     :string(50)
#  confirm_staff_code       :string(20)
#  confirm_staff_name       :string(50)
#  consolidated_billing     :boolean
#  contact2_dept_phone      :string(20)
#  contact2_name            :string(100)
#  contact2_name_kana       :string(100)
#  contact2_title           :string(50)
#  contact_dept_phone       :string(20)
#  contact_name             :string(100)
#  contact_name_kana        :string(100)
#  contact_title            :string(50)
#  contracted_at            :date
#  contractor_name_kana     :string(255)
#  customer_number          :string(20)       not null
#  email                    :string(255)
#  encrypted_password       :string           default(""), not null
#  failed_attempts          :integer          default(0), not null
#  fax_number               :string(20)
#  industry                 :string(50)
#  industry_sub             :string(50)
#  inventory_type           :string(50)
#  invoice_address          :string(500)
#  invoice_destination      :string(50)
#  invoice_name             :string(255)
#  invoice_name_kana        :string(255)
#  invoice_other_phone      :string(20)
#  invoice_phone            :string(20)
#  invoice_postal_code      :string(8)
#  lbc_code                 :string(20)
#  locked_at                :datetime
#  mobile_contact_person    :string(50)
#  mobile_phone             :string(20)
#  name                     :string(255)      not null
#  netmove_registered_at    :date
#  num_employees            :integer
#  num_offices              :integer
#  otp_attempts             :integer          default(0), not null
#  otp_code_digest          :string
#  otp_code_expires_at      :datetime
#  phone                    :string(20)
#  postal_code              :string(8)
#  prefecture               :string(20)
#  representative_name      :string(100)
#  representative_name_kana :string(100)
#  sales_mgmt_customer_code :string(20)
#  sms_mobile_number        :string(20)
#  status                   :string(50)       default("applied"), not null
#  town                     :string(100)
#  unlock_token             :string
#  years_in_business        :string(20)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agency_id                :uuid             not null
#  created_by_id            :uuid
#  netmove_member_id        :string(50)
#  sales_representative_id  :uuid
#  updated_by_id            :uuid
#
# Indexes
#
#  index_customers_on_agency_id                (agency_id)
#  index_customers_on_applied_at               (applied_at)
#  index_customers_on_customer_number          (customer_number) UNIQUE
#  index_customers_on_email                    (email) UNIQUE
#  index_customers_on_name                     (name)
#  index_customers_on_sales_representative_id  (sales_representative_id)
#  index_customers_on_status                   (status)
#  index_customers_on_unlock_token             (unlock_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (sales_representative_id => sales_representatives.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :customer do
    association :agency
    sequence(:name) { |n| "テスト顧客#{n}" }
  end
end
