# 営業担当者（04 R1・Column.md §7）。受注入力画面（R3）の認証キー=代理店CD＋営業担当者CD。
# T-2是正済み: sales_rep_code はLaravel現行が既にグローバルユニークなのでそのまま踏襲する。
class CreateSalesRepresentatives < ActiveRecord::Migration[8.1]
  def change
    create_table :sales_representatives, id: :uuid do |t|
      t.uuid    :agency_id,      null: false
      t.string  :sales_rep_code, null: false
      t.string  :name,           null: false
      t.string  :email
      t.string  :pdf_store_name
      t.string  :pdf_postal_code
      t.string  :pdf_prefecture
      t.string  :pdf_city
      t.string  :pdf_town
      t.string  :pdf_address_detail
      t.string  :pdf_phone_number
      t.string  :pdf_fax_number
      t.boolean :is_active, null: false, default: true

      t.uuid :created_by_id
      t.uuid :updated_by_id

      t.timestamps null: false
    end

    add_index :sales_representatives, :agency_id
    add_index :sales_representatives, :sales_rep_code, unique: true # T-2: グローバルユニーク
    add_index :sales_representatives, :email
    add_index :sales_representatives, :is_active
    add_foreign_key :sales_representatives, :agencies, on_delete: :restrict
    add_foreign_key :sales_representatives, :users, column: :created_by_id
    add_foreign_key :sales_representatives, :users, column: :updated_by_id
  end
end
