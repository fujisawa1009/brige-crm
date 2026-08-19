# 個人ごとの通知設定・社内スタッフ側（R6-1。04 04-rails-implementation-plan.md R6表参照。
# ftlogの notification_setting パターン（user_id × event_type、app_enabled/email_enabled の2カラム）
# をそのまま流用する。設定行が無いイベントはコード側デフォルト（StaffNotificationSetting::DEFAULT_*）に
# フォールバックするため、全ユーザー×全イベントを事前作成する必要はない（初回保存時のみ行を作る）。
class CreateStaffNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_notification_settings, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :event_type, null: false
      t.boolean :app_enabled, null: false, default: true
      t.boolean :email_enabled, null: false, default: true

      t.timestamps
    end

    add_index :staff_notification_settings, %i[user_id event_type], unique: true,
              name: "index_staff_notification_settings_on_user_and_event"

    add_foreign_key :staff_notification_settings, :users, on_delete: :cascade
  end
end
