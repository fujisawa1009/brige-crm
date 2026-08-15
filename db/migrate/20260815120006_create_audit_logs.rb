# 監査ログ（04 R0-7・ftlogのAuditable/AuthAuditable concernの移植先）。単一テナントのため
# organization_id/project_idは持たない（ftlog原本にあったテナント列を除去）。
# ログイン履歴画面（admin/login_histories）はこのテーブルをAuthAuditable::AUTH_ACTIONSで
# 絞り込むビューであり、専用テーブルではない（review-02の指摘どおり）。
# レコードは不変ログのため updated_at は持たせない。
class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.uuid   :user_id,       null: false
      t.string :user_type,     null: false # 将来のCustomer/SalesRepresentative向けに保持
      t.string :action,        null: false
      t.string :resource_type, null: false
      t.uuid   :resource_id
      t.string :resource_label
      t.jsonb  :changes_before
      t.jsonb  :changes_after
      t.jsonb  :metadata
      t.string :ip_address
      t.string :source
      t.string :request_id

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :user_id
    add_index :audit_logs, [:resource_type, :resource_id, :created_at], order: { created_at: :desc },
              name: "index_audit_logs_on_resource_and_created_at"
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at

    # user_type がUser以外（将来のCustomer等）になりうるため、FK制約は付けない
    # （ftlog原本もuser_idにFKなし。ポリモーフィックな参照を素直に表現する）
  end
end
