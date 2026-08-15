# == Schema Information
#
# Table name: sales_representatives
#
#  id                  :uuid             not null, primary key
#  email               :string
#  is_active           :boolean          default(TRUE), not null
#  name                :string           not null
#  otp_attempts        :integer          default(0), not null
#  otp_code_digest     :string
#  otp_code_expires_at :datetime
#  pdf_address_detail  :string
#  pdf_city            :string
#  pdf_fax_number      :string
#  pdf_phone_number    :string
#  pdf_postal_code     :string
#  pdf_prefecture      :string
#  pdf_store_name      :string
#  pdf_town            :string
#  sales_rep_code      :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  agency_id           :uuid             not null
#  created_by_id       :uuid
#  updated_by_id       :uuid
#
# Indexes
#
#  index_sales_representatives_on_agency_id       (agency_id)
#  index_sales_representatives_on_email           (email)
#  index_sales_representatives_on_is_active       (is_active)
#  index_sales_representatives_on_sales_rep_code  (sales_rep_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :sales_representative do
    association :agency
    sequence(:sales_rep_code) { |n| "SR#{n}" }
    sequence(:name) { |n| "営業担当#{n}" }
    is_active { true }
  end
end
