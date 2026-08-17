FactoryBot.define do
  factory :recipient_group do
    sequence(:name) { |n| "宛先グループ#{n}" }
    is_active { true }
  end
end
