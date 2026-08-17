# 一斉通知（04 R4）。既定は代理店宛の下書き。
FactoryBot.define do
  factory :notification do
    sequence(:title) { |n| "通知#{n}" }
    target_type { Notification::TARGET_AGENCY }
    status { Notification::STATUS_DRAFT }
    subject { "通知件名" }
    body { "通知本文" }
  end
end
