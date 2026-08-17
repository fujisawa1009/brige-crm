# 一斉通知（04 R4タスク3。Laravel Notification.php移植）。フィルタ(filter_params)・
# スケジュール送信(scheduled_at)・宛先種別(target_type)を持つ。実送信はNotificationDeliveryJob
# （Solid Queueのdelayed job。app/jobs/notification_delivery_job.rb）が担う。
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.string :title, null: false
      t.string :subject
      t.text :body
      # agency / customer（Laravel Notification::TARGET_TYPES踏襲）
      t.string :target_type, null: false
      t.jsonb :filter_params, null: false, default: {}
      # draft / scheduled / sending / sent / failed
      t.string :status, null: false, default: "draft"
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.integer :total_count, null: false, default: 0
      t.integer :success_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :notifications, :status
    add_index :notifications, :scheduled_at

    add_foreign_key :notifications, :users, column: :created_by_id
    add_foreign_key :notifications, :users, column: :updated_by_id
  end
end
