# 個人ごとの通知設定・社内スタッフ側（R6-1。db/migrate/20260820010000参照。ftlogの
# notification_setting パターンをそのまま流用: user_id × event_type の行を持ち、app_enabled/
# email_enabled の2カラムで管理する）。
#
# 設定行が存在しないイベントはコード側デフォルト（DEFAULT_APP_ENABLED/DEFAULT_EMAIL_ENABLED）に
# フォールバックする（NotificationSettingGate参照）。既定値はいずれもtrue＝この機能導入前の
# 「全イベント常時通知」という現行挙動を変えないオプトアウト方式にしている（オプトインにすると
# 導入直後に全員が無設定=通知ゼロになってしまうため）。行の事前作成（seed/コールバック）は行わない。
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
class StaffNotificationSetting < ApplicationRecord
  include Auditable

  DEFAULT_APP_ENABLED = true
  DEFAULT_EMAIL_ENABLED = true

  belongs_to :user

  validates :event_type, presence: true, inclusion: { in: NotificationEventType::ALL }
  validates :event_type, uniqueness: { scope: :user_id }
end
