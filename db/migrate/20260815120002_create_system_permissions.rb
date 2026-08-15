# エンドポイントRBAC・レイヤー1（03§3）。ルート署名(controller/action/http_method/path)を
# 権限単位にしたグローバルなカタログ。SystemPermissionSyncServiceがルーティングテーブルから
# 起動時に自動同期する（ftlogのSystemPermissionを単一テナント向けにそのまま移植）。
class CreateSystemPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :system_permissions, id: :uuid do |t|
      t.string  :controller,  null: false
      t.string  :action,      null: false
      t.string  :http_method, null: false
      t.string  :path,        null: false
      # admin / form / mypage の3区分（決定C）。formは authorize_system_permission! を
      # 完全スキップするため実質参照されないが、カタログ上は他区分と同様に記録する。
      t.string  :section,     null: false, default: "admin"
      t.boolean :enabled,     null: false, default: true
      t.string  :name

      t.timestamps null: false
    end

    add_index :system_permissions, [:controller, :action, :http_method, :path],
              unique: true, name: "index_system_permissions_on_route_signature"
    add_index :system_permissions, :enabled
    add_index :system_permissions, :section
  end
end
