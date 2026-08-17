# アプリ内通知（04 R4）。recipient は User または Customer（polymorphic）。expires_at は
# SystemNotification#assign_default_expiry が作成時に補完する。
FactoryBot.define do
  factory :system_notification do
    association :recipient, factory: :user
    notification_type { SystemNotification::TYPE_INQUIRY_CREATED }
    data { { "message" => "テスト通知" } }
  end
end
