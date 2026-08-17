# 一斉通知の送信結果（宛先ごとの成否記録。04 R4タスク3）。NotificationDeliveryJobが
# target_type/filter_paramsから宛先を展開する際に1レコードずつ作成し、送信結果(status)を更新する。
# total_count/success_count/failed_countの集計元にもなる（Notificationモデル側で都度再計算はしない
# 設計とし、送信ジョブが件数カラムを直接更新する。Laravel側の実装踏襲）。
class CreateNotificationRecipients < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_recipients, id: :uuid do |t|
      t.uuid :notification_id, null: false
      t.string :recipient_type, null: false
      t.uuid :recipient_id, null: false
      t.string :email
      # pending / sent / failed
      t.string :status, null: false, default: "pending"
      t.datetime :sent_at
      t.text :error_message

      t.timestamps
    end

    add_index :notification_recipients, :notification_id
    add_index :notification_recipients, %i[recipient_type recipient_id]

    add_foreign_key :notification_recipients, :notifications, on_delete: :cascade
  end
end
