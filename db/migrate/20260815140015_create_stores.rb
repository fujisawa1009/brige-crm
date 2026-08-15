# frozen_string_literal: true

# 04 R2タスク1（Column.md §9 jasmin_stores が正）。実装変更メモ（§9）どおり、住所は単一の
# address文字列ではなく postal_code〜address_detail の分割カラムで実装する。
class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores, id: :uuid do |t|
      t.uuid :customer_id, null: false
      t.string :store_code, limit: 20
      t.string :store_name, limit: 255, null: false
      t.string :store_name_kana, limit: 255
      t.string :postal_code, limit: 8
      t.string :prefecture, limit: 20
      t.string :city, limit: 50
      t.string :town, limit: 100
      t.string :address_detail, limit: 200
      t.string :phone_number, limit: 20
      t.string :fax_number, limit: 20
      t.string :business_hours_1, limit: 50
      t.string :business_hours_2, limit: 50
      t.string :regular_holiday, limit: 100
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :stores, :customer_id
    add_index :stores, :store_code
    add_index :stores, :is_active

    add_foreign_key :stores, :customers, on_delete: :cascade
    add_foreign_key :stores, :users, column: :created_by_id
    add_foreign_key :stores, :users, column: :updated_by_id
  end
end
