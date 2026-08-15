# ユーザー×ロールの多対多（ftlog移植）。単一テナントのため組織一致バリデーション（越境防止）は不要。
class CreateUserSystemRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_system_roles, id: :uuid do |t|
      t.uuid :user_id,        null: false
      t.uuid :system_role_id, null: false

      t.timestamps null: false
    end

    add_index :user_system_roles, [ :user_id, :system_role_id ], unique: true
    add_index :user_system_roles, :system_role_id

    add_foreign_key :user_system_roles, :users
    add_foreign_key :user_system_roles, :system_roles
  end
end
