# frozen_string_literal: true

# R5-1（04-rails-implementation-plan.md R5節、basic-design.md §9〜§12「契約ワークフロー状態機械」）:
# 不備チェック/差戻し/確認コール/契約確定の各節に散在していたステータスを「契約ステータス」として
# 1本化するマスタ。order_statuses/customer_statusesと同型（SystemManagedStatus）。
class CreateContractStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_statuses, id: :uuid do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.boolean :is_system, null: false, default: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :contract_statuses, :code, unique: true
    add_index :contract_statuses, %i[is_active sort_order]

    add_foreign_key :contract_statuses, :users, column: :created_by_id
    add_foreign_key :contract_statuses, :users, column: :updated_by_id

    # 新しいcodeは snake_case（例: confirm_call_pending）で旧string(10)を超えるため拡張する。
    # statusカラム(orders.status)と同じ50桁に揃える。
    change_column :orders, :contract_status, :string, limit: 50
  end
end
