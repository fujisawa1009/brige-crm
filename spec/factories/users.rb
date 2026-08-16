# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  is_active              :boolean          default(TRUE), not null
#  locked_at              :datetime
#  name                   :string           default(""), not null
#  otp_attempts           :integer          default(0), not null
#  otp_code_digest        :string
#  otp_code_expires_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  agency_group_id        :uuid
#  agency_id              :uuid
#
# Indexes
#
#  index_users_on_agency_group_id       (agency_group_id)
#  index_users_on_agency_id             (agency_id)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_group_id => agency_groups.id) ON DELETE => restrict
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#
FactoryBot.define do
  factory :user do
    sequence(:name)  { |n| "テストユーザー#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password1234" }
    password_confirmation { "Password1234" }

    # 04 R1: agency_id/agency_group_idで所属スコープを表現する（両方同時設定は不可。User#agency_scope_is_exclusive）。
    trait :agency_scoped do
      association :agency
    end

    trait :agency_group_scoped do
      association :agency_group
    end
  end
end
