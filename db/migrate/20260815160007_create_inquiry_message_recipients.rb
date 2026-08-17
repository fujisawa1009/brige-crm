# 問い合わせメッセージの宛先展開（04 R4タスク1。Laravel InquiryMessageRecipient移植）。
# 5型（agency/sales_representative/customer/user/recipient_group）にまたがるためRails標準の
# polymorphic association（recipient_type/recipient_id）で表現する。RecipientResolverが
# 案件から自動解決した宛先、または種別×ステータスのルーティング結果をここに書き込む。
class CreateInquiryMessageRecipients < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiry_message_recipients, id: :uuid do |t|
      t.uuid :inquiry_message_id, null: false
      t.string :recipient_type, null: false
      t.uuid :recipient_id, null: false

      t.timestamps
    end

    add_index :inquiry_message_recipients, :inquiry_message_id, name: "index_inquiry_message_recipients_on_message_id"
    add_index :inquiry_message_recipients, %i[recipient_type recipient_id]

    add_foreign_key :inquiry_message_recipients, :inquiry_messages, on_delete: :cascade
  end
end
