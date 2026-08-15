# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
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
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
FactoryBot.define do
  factory :user do
    sequence(:name)  { |n| "テストユーザー#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password1234" }
    password_confirmation { "Password1234" }
  end
end
