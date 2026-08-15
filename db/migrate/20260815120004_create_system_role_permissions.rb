# ロール×権限の中間テーブル（ftlog移植）。
class CreateSystemRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :system_role_permissions, id: :uuid do |t|
      t.uuid :system_role_id,       null: false
      t.uuid :system_permission_id, null: false

      t.timestamps null: false
    end

    add_index :system_role_permissions, [ :system_role_id, :system_permission_id ],
              unique: true, name: "index_system_role_permissions_on_role_and_permission"
    add_index :system_role_permissions, :system_permission_id

    add_foreign_key :system_role_permissions, :system_roles
    add_foreign_key :system_role_permissions, :system_permissions
  end
end
