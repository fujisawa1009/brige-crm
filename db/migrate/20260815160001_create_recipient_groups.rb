# 宛先グループ（04 R4タスク3。Laravel RecipientGroup移植）。一斉通知・問い合わせ宛先解決の
# どちらからも参照される（InquiryMessageRecipient.recipient_type="RecipientGroup"）。
class CreateRecipientGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :recipient_groups, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :recipient_groups, :is_active

    add_foreign_key :recipient_groups, :users, column: :created_by_id
    add_foreign_key :recipient_groups, :users, column: :updated_by_id
  end
end
