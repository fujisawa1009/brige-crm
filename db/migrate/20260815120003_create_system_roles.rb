# エンドポイントRBAC・ロール（03§3）。ftlogのSystemRoleから acts_as_tenant（organization_id）を
# 除去した単一テナント版（02のOrganizationRoleSeeder→RoleSeeder簡素化に対応）。
# 組み込み4ロール: admin(super_admin) / 実務運用者 / 代理店グループ用 / 代理店用（名称維持）。
class CreateSystemRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :system_roles, id: :uuid do |t|
      t.string  :name,         null: false # 不変キー。表示名変更はdisplay_nameで行う
      t.string  :display_name
      t.text    :description
      t.boolean :super_admin, null: false, default: false
      t.boolean :system,      null: false, default: false # 組み込みロール（削除・name変更不可）
      t.integer :position

      # 作成者/更新者の自動記録（TracksUser concern。04 R0-8）。ロール管理UIの編集履歴用。
      t.uuid :created_by_id
      t.uuid :updated_by_id

      t.timestamps null: false
    end

    add_index :system_roles, :name, unique: true
    add_index :system_roles, :position
    add_index :system_roles, :system
    add_foreign_key :system_roles, :users, column: :created_by_id
    add_foreign_key :system_roles, :users, column: :updated_by_id
  end
end
