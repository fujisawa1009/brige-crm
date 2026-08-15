FactoryBot.define do
  factory :system_role do
    sequence(:name) { |n| "role-#{n}" }
    display_name { name }
    super_admin { false }
    system { false }
  end
end
