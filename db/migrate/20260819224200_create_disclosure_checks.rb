# frozen_string_literal: true

# R5-13（contract-confirmation-docs.md §3-1）: 重説チェックの実施記録ヘッダ（誰が・いつ・どの版で）。
# Q-3決定により案件単位（order_id）で確定。application_idは持たない。
# performed_by はポリモーフィック（実装対象はQ-2決定によりCustomer一択だが、将来拡張余地として残す）。
# UPDATEで上書きせず追記型（コンプライアンス証跡。同一Orderに複数回実施記録が残ってよい）。
class CreateDisclosureChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :disclosure_checks, id: :uuid do |t|
      t.uuid   :order_id, null: false
      t.uuid   :disclosure_item_set_id, null: false
      t.datetime :performed_at, null: false
      t.string :performed_by_type, null: false
      t.uuid   :performed_by_id, null: false
      # Q-2決定＝"web_check"固定。inclusion validationはモデル側（enumは使わない方針。
      # master-data-design-policy.md）。
      t.string :method, null: false, default: "web_check"
      t.string :result, null: false

      t.timestamps
    end

    add_index :disclosure_checks, :order_id
    add_index :disclosure_checks, [ :performed_by_type, :performed_by_id ]

    add_foreign_key :disclosure_checks, :orders
    add_foreign_key :disclosure_checks, :disclosure_item_sets
  end
end
