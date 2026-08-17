# 宛先グループのメンバー（04 R4タスク3。Laravel RecipientGroupMember移植）。
# recipient は User または ProductionCompany の2種のみ（Laravel実装踏襲。代理店/営業/顧客は
# InquiryMessageRecipient側で案件経由に個別解決されるため、グループには載せない）。
# Rails標準のpolymorphic association（recipient_type/recipient_id）で表現する。
class CreateRecipientGroupMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :recipient_group_members, id: :uuid do |t|
      t.uuid :recipient_group_id, null: false
      t.string :recipient_type, null: false
      t.uuid :recipient_id, null: false

      t.timestamps
    end

    add_index :recipient_group_members, :recipient_group_id, name: "index_recipient_group_members_on_group_id"
    add_index :recipient_group_members, %i[recipient_type recipient_id]
    add_index :recipient_group_members, %i[recipient_group_id recipient_type recipient_id],
              unique: true, name: "index_recipient_group_members_on_group_and_recipient"

    add_foreign_key :recipient_group_members, :recipient_groups, on_delete: :cascade
  end
end
