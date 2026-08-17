# 宛先グループメンバー（04 R4）。recipient は User または ProductionCompany（polymorphic）。
FactoryBot.define do
  factory :recipient_group_member do
    association :recipient_group
    association :recipient, factory: :user
  end
end
