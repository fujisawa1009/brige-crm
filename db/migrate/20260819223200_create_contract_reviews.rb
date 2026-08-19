# frozen_string_literal: true

# R5-1（basic-design.md §9〜§12、contract-confirmation-docs.md）: 契約ワークフロー状態機械の
# 遷移履歴・差戻し内容を保持する追記型ログ（disclosure_checksと同じ思想。UPDATEで上書きしない）。
# 監査ログ(AuditLog)は audit_logs.user_id が NOT NULL のため、ログイン中のUserを前提としない
# 汎用の操作記録はここで完結させる（payment_transaction_logsと同じ設計判断。payment-integration.md §4-5）。
class CreateContractReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_reviews, id: :uuid do |t|
      t.uuid   :order_id,   null: false
      t.string :event,      null: false
      t.string :from_status
      t.string :to_status,  null: false
      t.text   :reason
      t.jsonb  :target_fields, null: false, default: {}
      t.text   :comment
      # 差戻し先（basic-design.md §10）。営業担当者/顧客のどちらが修正主体かを明示する。
      # 差戻し以外のイベントではnull。
      t.string :returned_to
      t.uuid     :performed_by_id
      t.datetime :performed_at, null: false

      t.datetime :created_at, null: false
    end

    add_index :contract_reviews, :order_id
    add_index :contract_reviews, [ :order_id, :performed_at ]

    add_foreign_key :contract_reviews, :orders, column: :order_id
    add_foreign_key :contract_reviews, :users, column: :performed_by_id
  end
end
