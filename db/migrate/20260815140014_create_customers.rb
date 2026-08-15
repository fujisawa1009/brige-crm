# frozen_string_literal: true

# 04 R2タスク1（Column.md §8 jasmin_customers が正）。CTO決定（03§8-2・04 R2冒頭）どおり
# モデル名Customer・テーブル名customersで実装する。
#
# T-3是正（03§5・app/models/contract_condition.rb申し送り）: Laravel現行はcontract_condition_idを
# customers側に持つが、「受注（orders）側に持たせる」是正方針のため、本テーブルには
# contract_condition_id を持たせない（→ orders.contract_condition_id に一本化）。
#
# 実装注記（Column.md §8 連絡先セクション）: `phone_number`という列名は使わず、既存踏襲で`phone`と
# する（Laravel実装注記をそのまま踏襲）。
class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers, id: :uuid do |t|
      # 基本・管理情報
      t.string :customer_number, limit: 20, null: false
      t.string :name, limit: 255, null: false
      t.uuid :agency_id, null: false
      t.uuid :sales_representative_id
      # customer_statuses.code を参照する値（DB外FK。SystemManagedStatus側のcodeは可変長のためRails標準の
      # 参照整合性チェックはモデルバリデーションで行う。理由はapp/models/customer.rbコメント参照）。
      t.string :status, limit: 50, null: false, default: "applied"
      t.date :applied_at
      t.date :contracted_at

      # 契約者基本情報
      t.string :applicant_type, limit: 20
      t.string :agency_customer_code, limit: 50
      t.string :inventory_type, limit: 50
      t.string :contractor_name_kana, limit: 255

      # 法人代表者情報
      t.string :representative_name, limit: 100
      t.string :representative_name_kana, limit: 100

      # 担当者情報1
      t.string :contact_name, limit: 100
      t.string :contact_name_kana, limit: 100
      t.string :contact_title, limit: 50
      t.string :contact_dept_phone, limit: 20

      # 担当者情報2
      t.string :contact2_name, limit: 100
      t.string :contact2_name_kana, limit: 100
      t.string :contact2_title, limit: 50
      t.string :contact2_dept_phone, limit: 20

      # 契約者住所
      t.string :postal_code, limit: 8
      t.string :prefecture, limit: 20
      t.string :city, limit: 50
      t.string :town, limit: 100
      t.string :address_detail, limit: 200

      # 連絡先
      t.string :phone, limit: 20
      t.string :fax_number, limit: 20
      t.string :mobile_phone, limit: 20
      t.string :mobile_contact_person, limit: 50
      t.string :email, limit: 255

      # 業種・事業情報
      t.string :industry, limit: 50
      t.string :industry_sub, limit: 50
      t.string :years_in_business, limit: 20
      t.integer :num_employees
      t.integer :num_offices

      # 請求書送付先情報
      t.boolean :consolidated_billing
      t.string :invoice_destination, limit: 50
      t.string :invoice_name, limit: 255
      t.string :invoice_name_kana, limit: 255
      t.string :invoice_postal_code, limit: 8
      t.string :invoice_address, limit: 500
      t.string :invoice_phone, limit: 20
      t.string :invoice_other_phone, limit: 20

      # スタッフ・担当者コード
      t.string :confirm_staff_code, limit: 20
      t.string :confirm_staff_name, limit: 50
      t.string :appointer_code, limit: 20
      t.string :appointer_name, limit: 50

      # 外部システム連携
      t.string :lbc_code, limit: 20
      t.string :sales_mgmt_customer_code, limit: 20
      t.string :netmove_member_id, limit: 50
      t.date :netmove_registered_at
      t.string :sms_mobile_number, limit: 20

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :customers, :customer_number, unique: true
    add_index :customers, :name
    add_index :customers, :agency_id
    add_index :customers, :sales_representative_id
    add_index :customers, :status
    add_index :customers, :applied_at

    add_foreign_key :customers, :agencies, on_delete: :restrict
    add_foreign_key :customers, :sales_representatives, on_delete: :nullify
    add_foreign_key :customers, :users, column: :created_by_id
    add_foreign_key :customers, :users, column: :updated_by_id
  end
end
