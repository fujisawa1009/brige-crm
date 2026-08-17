# 問い合わせメッセージ（04 R4）。inquiry と本文が必須。
FactoryBot.define do
  factory :inquiry_message do
    association :inquiry
    sequence(:body) { |n| "メッセージ本文#{n}" }
  end
end
