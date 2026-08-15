# users への代理店/代理店グループ所属列追加（04 R1・Laravel User.php踏襲）。
#
# 運用規約（01§2-1・User#agency_scope_is_exclusive で担保）:
#   admin / 実務運用者:   agency_group_id・agency_id とも NULL（Pundit AgencyScoped の staff_scope）
#   代理店グループ担当者: agency_group_id のみ設定
#   代理店担当者:         agency_id のみ設定（agency_group は agency 経由で取得）
#
# is_active はLaravel User.phpに合わせて追加（管理画面からの有効/無効切替。無効時はログイン不可に
# するため User#active_for_authentication? をあわせて上書きする）。
class AddAgencyColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :agency_group_id, :uuid
    add_column :users, :agency_id, :uuid
    add_column :users, :is_active, :boolean, null: false, default: true

    add_index :users, :agency_group_id
    add_index :users, :agency_id
    add_foreign_key :users, :agency_groups, on_delete: :nullify
    add_foreign_key :users, :agencies, on_delete: :nullify
  end
end
