# 通知テンプレート（04 R4）。template_type は notification/inquiry/common のいずれか。
FactoryBot.define do
  factory :notification_template do
    sequence(:name) { |n| "テンプレート#{n}" }
    template_type { NotificationTemplate::TYPE_NOTIFICATION }
    subject { "テンプレート件名" }
    body { "テンプレート本文" }
  end
end
