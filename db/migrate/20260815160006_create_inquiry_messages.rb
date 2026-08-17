# 問い合わせメッセージ（04 R4タスク1。Laravel InquiryMessage.php移植）。
# 添付は Active Storage の has_many_attached で持たせる（専用テーブル不要。20260815150007で
# active_storage_* テーブルは追加済み）。
class CreateInquiryMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiry_messages, id: :uuid do |t|
      t.uuid :inquiry_id, null: false
      t.text :body, null: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :inquiry_messages, %i[inquiry_id created_at], name: "index_inquiry_messages_on_inquiry_and_created_at"

    add_foreign_key :inquiry_messages, :inquiries, on_delete: :cascade
    add_foreign_key :inquiry_messages, :users, column: :created_by_id
    add_foreign_key :inquiry_messages, :users, column: :updated_by_id
  end
end
