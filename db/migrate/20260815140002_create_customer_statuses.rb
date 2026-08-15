# frozen_string_literal: true

# 04 R2タスク4: 顧客ステータスのDB管理化（Laravel移行元は database/migrations/
# 2026_06_12_000001_create_customer_statuses_table.php。code/label/is_system方針を踏襲）。
class CreateCustomerStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_statuses, id: :uuid do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      # true = システム定義（削除不可・code変更不可。Customer#assign_customer_number等コードから参照する）
      t.boolean :is_system, null: false, default: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :customer_statuses, :code, unique: true
    add_index :customer_statuses, %i[is_active sort_order]

    add_foreign_key :customer_statuses, :users, column: :created_by_id
    add_foreign_key :customer_statuses, :users, column: :updated_by_id
  end
end
