# == Schema Information
#
# Table name: order_work_details
#
#  id                           :uuid             not null, primary key
#  accepted_cards               :string(200)
#  attribute_1                  :string(100)
#  attribute_10                 :string(100)
#  attribute_11                 :string(100)
#  attribute_2                  :string(100)
#  attribute_3                  :string(100)
#  attribute_4                  :string(100)
#  attribute_5                  :string(100)
#  attribute_6                  :string(100)
#  attribute_7                  :string(100)
#  attribute_8                  :string(100)
#  attribute_9                  :string(100)
#  available_from               :string(30)
#  barrier_free                 :string(10)
#  business_account_name        :string(100)
#  business_category_keyword    :string(200)
#  business_type                :string(30)
#  capital                      :string(50)
#  contact_easy_day             :string(100)
#  contact_easy_day_note        :string(200)
#  contact_easy_time            :string(100)
#  contact_easy_time_note       :string(200)
#  dinner_hours                 :string(30)
#  directions                   :string(500)
#  facebook_pass                :text
#  gbp_delete_new               :string(10)
#  gbp_owner_contact            :string(100)
#  gbp_owner_name               :string(100)
#  gbp_owner_permission         :string(20)
#  gbp_owner_permission_granted :string(20)
#  gbp_permission               :string(30)
#  gbp_site_url                 :string(500)
#  gbp_url                      :string(500)
#  google_account_pass          :text
#  has_facebook                 :string(10)
#  has_google_business          :string(10)
#  has_instagram                :string(10)
#  hearing_system               :string(50)
#  industry_keyword             :string(200)
#  instagram_account            :string(20)
#  instagram_login_confirmed    :string(20)
#  instagram_pass               :text
#  keyword_area_1               :string(50)
#  keyword_area_2               :string(50)
#  keyword_area_3               :string(50)
#  keyword_city                 :string(50)
#  keyword_industry_main        :string(50)
#  keyword_industry_sub1        :string(50)
#  keyword_industry_sub2        :string(50)
#  keyword_industry_sub3        :string(50)
#  keyword_industry_sub4        :string(50)
#  keyword_prefecture           :string(20)
#  keyword_region_industry      :string(200)
#  keyword_remarks              :text
#  logo_photo                   :string(100)
#  lunch_hours                  :string(30)
#  nearest_station              :string(100)
#  num_employees                :integer
#  num_stores                   :integer
#  opening_date                 :date
#  operation_history            :text
#  order_time                   :string(30)
#  parking                      :string(20)
#  parking_capacity             :integer
#  reference_url                :string(500)
#  system_account_pass          :text
#  wifi_available               :string(30)
#  work_progress_notes          :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  created_by_id                :uuid
#  facebook_id                  :text
#  google_account_id            :text
#  instagram_id                 :text
#  order_id                     :uuid             not null
#  system_account_id            :text
#  updated_by_id                :uuid
#
# Indexes
#
#  index_order_work_details_on_order_id  (order_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :order_work_detail do
    association :order
    system_account_id { "sys-account-001" }
    system_account_pass { "sys-pass-001" }
  end
end
