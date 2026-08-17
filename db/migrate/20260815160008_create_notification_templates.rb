# 通知テンプレート（04 R4タスク3。Laravel NotificationTemplate.php移植）。
class CreateNotificationTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_templates, id: :uuid do |t|
      t.string :name, null: false
      # notification(一斉通知用) / inquiry(問い合わせ用) / common(共通)
      t.string :template_type, null: false
      t.string :subject
      t.text :body

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :notification_templates, :template_type

    add_foreign_key :notification_templates, :users, column: :created_by_id
    add_foreign_key :notification_templates, :users, column: :updated_by_id
  end
end
