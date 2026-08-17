# 種別×ステータス→宛先グループのルーティング（04 R4）。status_code は inquiry_statuses に
# 存在する必要があるため :seed_status_catalog タグ前提。既定はアフター問合せの「未対応」。
FactoryBot.define do
  factory :inquiry_recipient_route do
    association :recipient_group
    category { Inquiry::CATEGORY_AFTER }
    status_code { "未対応" }
  end
end
