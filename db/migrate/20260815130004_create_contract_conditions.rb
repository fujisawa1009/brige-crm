# 契約条件バージョン（04 R1・Column.md §6）。代理店ごとに契約条件変更のたびに新規レコードを追加し、
# 旧バージョンの effective_until に終了日を設定する。現行バージョンは effective_until = NULL。
#
# 申し送り（T-3・03§5・04 R1本文）: 「受注（Order）側に contract_condition_id を持たせる」是正は
# OrderモデルがまだR2で作られていないため未実施。R1では Agency 1─* ContractCondition の単体CRUDのみ
# 実装する。R2でOrderモデルを作る際に orders.contract_condition_id（FK, not null）を追加すること。
class CreateContractConditions < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_conditions, id: :uuid do |t|
      t.uuid   :agency_id,       null: false
      t.string :name,            null: false
      t.date   :effective_from,  null: false
      t.date   :effective_until

      t.uuid :created_by_id
      t.uuid :updated_by_id

      t.timestamps null: false
    end

    add_index :contract_conditions, :agency_id
    add_index :contract_conditions, :effective_until
    add_foreign_key :contract_conditions, :agencies, on_delete: :cascade
    add_foreign_key :contract_conditions, :users, column: :created_by_id
    add_foreign_key :contract_conditions, :users, column: :updated_by_id
  end
end
