# 代理店グループ（04 R1・Column.md §1）。傘下の agencies を束ねる基点。
# group_code はログインID表示用の業務識別子（実際の認証は users.email。Column.md §1備考）。
class CreateAgencyGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :agency_groups, id: :uuid do |t|
      t.string  :name,        null: false
      t.string  :service_type, null: false # 'Bridge' / 'BridgePlus'（Column.md §1）
      t.string  :group_code,  null: false
      t.string  :contact_email
      t.string  :bridge_plan_display_type # 'ハイブリッド' / 'プラン全表示'
      t.boolean :csv_download_visible

      t.uuid :created_by_id
      t.uuid :updated_by_id

      t.timestamps null: false
    end

    add_index :agency_groups, :name
    add_index :agency_groups, :group_code, unique: true
    add_foreign_key :agency_groups, :users, column: :created_by_id
    add_foreign_key :agency_groups, :users, column: :updated_by_id
  end
end
