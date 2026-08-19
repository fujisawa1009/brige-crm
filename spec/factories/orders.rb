# Order#assign_default_statusの既定値（OrderStatus::CODE_ORDERED = "0:受注"）が存在することを
# 前提とする（spec/factories/customers.rbと同じ理由。:seed_status_catalogタグを使うこと）。
# == Schema Information
#
# Table name: orders
#
#  id                             :uuid             not null, primary key
#  account_issued_at              :date
#  accounting_month               :string(6)
#  billing_password               :text
#  bridge_accounting_month        :string(6)
#  bridge_agency_name             :string(100)
#  bridge_migration               :string(5)
#  bridge_migration_order_number  :string(20)
#  bridge_sales_rep_name          :string(50)
#  bundle_target_order_number     :string(20)
#  bundled_billing                :string(5)
#  business_auth_doc              :string(5)
#  business_auth_doc_collected_at :date
#  business_proof                 :string(200)
#  cancelled_at                   :date
#  citation_applied               :string(5)
#  citation_count                 :integer
#  citation_existing_serial       :string(50)
#  citation_plan                  :string(50)
#  confirm_call_contact_name      :string(50)
#  confirm_call_notes             :text
#  confirm_call_preferred_date    :string(50)
#  confirm_call_remarks           :text
#  confirm_call_staff_name        :string(50)
#  confirm_call_time              :string(100)
#  consent_contact_age            :integer
#  consent_rep_age                :integer
#  consent_status                 :string(20)
#  contract_sent_at               :date
#  contract_start_date            :date
#  contract_status                :string(50)
#  domestic_citation_plan         :string(50)
#  elderly_consent                :string(5)
#  elderly_consent_collected_at   :date
#  external_link_applied          :string(5)
#  external_link_count            :integer
#  external_link_type             :string(20)
#  factor_notes                   :string(200)
#  finance_address_detail         :string(100)
#  finance_building               :string(100)
#  finance_city                   :string(50)
#  finance_division               :string(20)
#  finance_installer              :string(100)
#  finance_phone                  :string(20)
#  finance_postal_code            :string(8)
#  finance_prefecture             :string(20)
#  finance_town                   :string(100)
#  gbp_multilingual               :string(5)
#  google_ads_applied             :string(5)
#  google_ads_count               :integer
#  google_review_display          :string(5)
#  infobiz_applied                :string(5)
#  inspection_call_completed_at   :date
#  inspection_call_history        :text
#  inspection_call_ng_time        :string(100)
#  issued_at                      :date
#  language_selection             :string(100)
#  meo_existing_serial            :string(50)
#  meo_mgmt_number                :string(20)
#  meo_premium_applied            :string(5)
#  onerank_cms                    :string(5)
#  order_number                   :string(20)       not null
#  ordered_at                     :date
#  owlet_cms                      :string(5)
#  paper_address_note             :string(200)
#  payment_collected_at           :date
#  payment_doc_confirmed_at       :date
#  payment_method                 :string(50)
#  plus_applied                   :string(5)
#  portal_site_applied            :string(5)
#  remarks                        :text
#  reservation_system             :string(50)
#  review_heading                 :string(100)
#  s_plan_cms                     :string(5)
#  sales_mgmt_slip_number         :string(20)
#  shared_notes                   :text
#  status                         :string(50)       default("0:受注"), not null
#  terminated_at                  :date
#  termination_reason             :string(200)
#  toss_up_code                   :string(20)
#  work_completed_at              :date
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  agency_id                      :uuid             not null
#  contract_condition_id          :uuid             not null
#  created_by_id                  :uuid
#  customer_id                    :uuid             not null
#  member_id                      :string(20)
#  plan_id                        :uuid
#  product_initial_fee_id         :uuid
#  sales_representative_id        :uuid
#  serial_id                      :string(20)
#  store_id                       :uuid
#  updated_by_id                  :uuid
#
# Indexes
#
#  index_orders_on_agency_id                (agency_id)
#  index_orders_on_contract_condition_id    (contract_condition_id)
#  index_orders_on_customer_id              (customer_id)
#  index_orders_on_order_number             (order_number) UNIQUE
#  index_orders_on_plan_id                  (plan_id)
#  index_orders_on_product_initial_fee_id   (product_initial_fee_id)
#  index_orders_on_sales_representative_id  (sales_representative_id)
#  index_orders_on_status                   (status)
#  index_orders_on_store_id                 (store_id)
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (contract_condition_id => contract_conditions.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (customer_id => customers.id) ON DELETE => restrict
#  fk_rails_...  (plan_id => plans.id) ON DELETE => nullify
#  fk_rails_...  (product_initial_fee_id => product_initial_fees.id) ON DELETE => nullify
#  fk_rails_...  (sales_representative_id => sales_representatives.id) ON DELETE => nullify
#  fk_rails_...  (store_id => stores.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :order do
    association :customer
    association :agency
    association :contract_condition
  end
end
