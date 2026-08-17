# 問い合わせ（04 R4）。status は category から Inquiry#assign_default_status が既定値を割り当てるが、
# その既定コードが inquiry_statuses に存在する必要があるため、このfactoryを使うspecは
# :seed_status_catalog タグ（StatusSeeder が inquiry_statuses も投入する）を付けること。
FactoryBot.define do
  factory :inquiry do
    association :order
    category { Inquiry::CATEGORY_AFTER }
    sequence(:title) { |n| "問い合わせ#{n}" }
  end
end
