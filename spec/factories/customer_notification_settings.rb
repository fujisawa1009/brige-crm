# 個人ごとの通知設定・顧客側（R6-1）。
# == Schema Information
#
# Table name: customer_notification_settings
#
#  id            :uuid             not null, primary key
#  app_enabled   :boolean          default(TRUE), not null
#  email_enabled :boolean          default(TRUE), not null
#  event_type    :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  customer_id   :uuid             not null
#
# Indexes
#
#  index_customer_notification_settings_on_customer_and_event  (customer_id,event_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :customer_notification_setting do
    association :customer
    event_type { NotificationEventType::APPLICATION_CONFIRMED }
    app_enabled { true }
    email_enabled { true }
  end
end
