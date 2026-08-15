# 代理店（04 R1・Column.md §2）。agency_group_id で代理店グループに所属する。
# email_1〜5 は通知先メール（ログイン認証とは別。Column.md §2備考）。
class CreateAgencies < ActiveRecord::Migration[8.1]
  def change
    create_table :agencies, id: :uuid do |t|
      t.uuid    :agency_group_id, null: false
      t.string  :name,            null: false
      t.string  :agency_code,     null: false
      t.string  :contact_person
      t.string  :email_1
      t.string  :email_2
      t.string  :email_3
      t.string  :email_4
      t.string  :email_5
      t.boolean :electronic_contract_enabled
      t.boolean :csv_download_visible

      t.uuid :created_by_id
      t.uuid :updated_by_id

      t.timestamps null: false
    end

    add_index :agencies, :agency_group_id
    add_index :agencies, :name
    add_index :agencies, :agency_code, unique: true
    add_foreign_key :agencies, :agency_groups, on_delete: :restrict
    add_foreign_key :agencies, :users, column: :created_by_id
    add_foreign_key :agencies, :users, column: :updated_by_id
  end
end
