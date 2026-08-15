FactoryBot.define do
  factory :user do
    sequence(:name)  { |n| "テストユーザー#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password1234" }
    password_confirmation { "Password1234" }
  end
end
