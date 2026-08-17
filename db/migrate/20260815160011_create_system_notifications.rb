# アプリ内通知（04 R4タスク4。Laravel SystemNotification移植）。recipient（受信者。User or Customer）
# はRails標準polymorphic association。Solid Cable経由でリアルタイム配信し（app/models/system_notification.rb
# の after_create_commit）、30日で自動prune（config/recurring.yml参照）する。
class CreateSystemNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :system_notifications, id: :uuid do |t|
      t.string :recipient_type, null: false
      t.uuid :recipient_id, null: false
      # inquiry_created / inquiry_replied / application_completed / notification_sent 等
      t.string :notification_type, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :read_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :system_notifications, %i[recipient_type recipient_id read_at],
              name: "index_system_notifications_on_recipient_and_read_at"
    add_index :system_notifications, :expires_at
  end
end
