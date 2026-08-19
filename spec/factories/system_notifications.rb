# アプリ内通知（04 R4）。recipient は User または Customer（polymorphic）。expires_at は
# SystemNotification#assign_default_expiry が作成時に補完する。
# == Schema Information
#
# Table name: system_notifications
#
#  id                :uuid             not null, primary key
#  data              :jsonb            not null
#  expires_at        :datetime         not null
#  notification_type :string           not null
#  read_at           :datetime
#  recipient_type    :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  recipient_id      :uuid             not null
#
# Indexes
#
#  index_system_notifications_on_expires_at             (expires_at)
#  index_system_notifications_on_recipient_and_read_at  (recipient_type,recipient_id,read_at)
#
FactoryBot.define do
  factory :system_notification do
    association :recipient, factory: :user
    notification_type { SystemNotification::TYPE_INQUIRY_CREATED }
    data { { "message" => "テスト通知" } }
  end
end
