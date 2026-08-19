# 個人ごとの通知設定・顧客側（R6-1。db/migrate/20260820010100参照。2026-08-20 CEO決定＝顧客本人ごとに
# 個別設定できるようにする。ftlogが後にプロジェクト単位（管理者が代理設定）へ置き換えた設計とは異なり、
# 顧客本人がマイページから自分の設定を編集する運用のため、参考実装のない新規設計。社内スタッフ側
# （StaffNotificationSetting）と対称の customer_id × event_type + app_enabled/email_enabled 構造。
#
# 設定行が存在しないイベントはコード側デフォルトにフォールバックする（NotificationSettingGate参照）。
# 既定値はStaffNotificationSettingと同じくtrue/true（オプトアウト方式。導入前の「全イベント常時通知」
# という現行挙動を変えない）。
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
class CustomerNotificationSetting < ApplicationRecord
  include Auditable

  DEFAULT_APP_ENABLED = true
  DEFAULT_EMAIL_ENABLED = true

  belongs_to :customer

  validates :event_type, presence: true, inclusion: { in: NotificationEventType::ALL }
  validates :event_type, uniqueness: { scope: :customer_id }
end
