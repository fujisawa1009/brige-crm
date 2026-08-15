# frozen_string_literal: true

# 04 R2タスク1（Column.md §10 jasmin_orders が正。約90フィールド）。CTO決定どおりモデル名Order・
# テーブル名ordersで実装する。
#
# T-3是正の反映（R1申し送り。app/models/contract_condition.rbコメント参照）:
# contract_condition_id をここに追加する（FK, not null＝受注時点の契約条件バージョンを固定参照）。
#
# billing_password は pii-handling-rules.md §1 分類B（外部認証情報＝請求パスワード）に該当するため
# ActiveRecord::Encryption対象（app/models/order.rb の encrypts宣言）。暗号化後の値は平文よりかなり
# 長くなるため t.text にしている（他のPII-B対象と揃えたapp/models/order_work_detail.rbも同様）。
class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders, id: :uuid do |t|
      # 基本・識別情報
      t.string :order_number, limit: 20, null: false
      t.uuid :customer_id, null: false
      t.uuid :store_id
      t.uuid :sales_representative_id
      t.uuid :agency_id, null: false
      t.uuid :contract_condition_id, null: false
      t.string :serial_id, limit: 20

      # プラン・初期費用・支払方法
      t.uuid :plan_id
      t.uuid :product_initial_fee_id
      t.string :payment_method, limit: 50
      t.string :plus_applied, limit: 5

      # ステータス（order_statuses.code参照。DB外FKの理由はcustomers.statusと同じ）
      t.string :status, limit: 50, null: false, default: "0:受注"
      t.string :contract_status, limit: 10

      # 日付管理
      t.date :ordered_at
      t.date :contract_start_date
      t.date :contract_sent_at
      t.date :issued_at
      t.date :account_issued_at
      t.date :work_completed_at
      t.string :accounting_month, limit: 6
      t.string :bridge_accounting_month, limit: 6
      t.date :payment_collected_at
      t.date :payment_doc_confirmed_at
      t.date :cancelled_at
      t.date :terminated_at
      t.string :termination_reason, limit: 200

      # 確認コール情報
      t.string :confirm_call_staff_name, limit: 50
      t.text :confirm_call_notes
      t.string :confirm_call_preferred_date, limit: 50
      t.string :confirm_call_time, limit: 100
      t.string :confirm_call_contact_name, limit: 50
      t.text :confirm_call_remarks

      # 検収コール情報
      t.string :inspection_call_ng_time, limit: 100
      t.text :inspection_call_history
      t.date :inspection_call_completed_at

      # 書類・同意
      t.string :elderly_consent, limit: 5
      t.date :elderly_consent_collected_at
      t.string :business_auth_doc, limit: 5
      t.date :business_auth_doc_collected_at
      t.string :business_proof, limit: 200
      t.string :consent_status, limit: 20
      t.integer :consent_rep_age
      t.integer :consent_contact_age
      t.string :paper_address_note, limit: 200

      # 財務・請求
      t.string :sales_mgmt_slip_number, limit: 20
      t.string :factor_notes, limit: 200
      t.string :bundled_billing, limit: 5
      t.string :bundle_target_order_number, limit: 20
      t.string :finance_division, limit: 20
      t.string :finance_installer, limit: 100
      t.string :finance_postal_code, limit: 8
      t.string :finance_prefecture, limit: 20
      t.string :finance_city, limit: 50
      t.string :finance_town, limit: 100
      t.string :finance_address_detail, limit: 100
      t.string :finance_building, limit: 100
      t.string :finance_phone, limit: 20

      # 外部システム連携（billing_passwordは分類B。PII暗号化対象）
      t.string :member_id, limit: 20
      t.text :billing_password
      t.string :meo_mgmt_number, limit: 20
      t.string :toss_up_code, limit: 20

      # Bridge移行情報
      t.string :bridge_migration, limit: 5
      t.string :bridge_migration_order_number, limit: 20
      t.string :bridge_agency_name, limit: 100
      t.string :bridge_sales_rep_name, limit: 50

      # 追加サービス申込
      t.string :citation_applied, limit: 5
      t.integer :citation_count
      t.string :citation_existing_serial, limit: 50
      t.string :domestic_citation_plan, limit: 50
      t.string :citation_plan, limit: 50
      t.string :s_plan_cms, limit: 5
      t.string :owlet_cms, limit: 5
      t.string :onerank_cms, limit: 5
      t.string :external_link_applied, limit: 5
      t.integer :external_link_count
      t.string :external_link_type, limit: 20
      t.string :gbp_multilingual, limit: 5
      t.string :language_selection, limit: 100
      t.string :meo_existing_serial, limit: 50
      t.string :infobiz_applied, limit: 5
      t.string :meo_premium_applied, limit: 5
      t.string :google_ads_applied, limit: 5
      t.integer :google_ads_count
      t.string :google_review_display, limit: 5
      t.string :review_heading, limit: 100
      t.string :reservation_system, limit: 50
      t.string :portal_site_applied, limit: 5

      # メモ・備考
      t.text :remarks
      t.text :shared_notes

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :customer_id
    add_index :orders, :store_id
    add_index :orders, :sales_representative_id
    # 案件一覧のアクセス制御（Pundit AgencyScoped）に使う最重要インデックス（Column.md §10備考）。
    add_index :orders, :agency_id
    add_index :orders, :contract_condition_id
    add_index :orders, :plan_id
    add_index :orders, :product_initial_fee_id
    add_index :orders, :status

    add_foreign_key :orders, :customers, on_delete: :restrict
    add_foreign_key :orders, :stores, on_delete: :nullify
    add_foreign_key :orders, :sales_representatives, on_delete: :nullify
    add_foreign_key :orders, :agencies, on_delete: :restrict
    add_foreign_key :orders, :contract_conditions, on_delete: :restrict
    add_foreign_key :orders, :plans, on_delete: :nullify
    add_foreign_key :orders, :product_initial_fees, on_delete: :nullify
    add_foreign_key :orders, :users, column: :created_by_id
    add_foreign_key :orders, :users, column: :updated_by_id
  end
end
