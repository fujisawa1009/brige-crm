# 個人ごとの通知設定・社内スタッフ側（R6-1）。
# == Schema Information
#
# Table name: staff_notification_settings
#
#  id            :uuid             not null, primary key
#  app_enabled   :boolean          default(TRUE), not null
#  email_enabled :boolean          default(TRUE), not null
#  event_type    :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :uuid             not null
#
# Indexes
#
#  index_staff_notification_settings_on_user_and_event  (user_id,event_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :staff_notification_setting do
    association :user
    event_type { NotificationEventType::APPLICATION_RECEIVED }
    app_enabled { true }
    email_enabled { true }
  end
end
