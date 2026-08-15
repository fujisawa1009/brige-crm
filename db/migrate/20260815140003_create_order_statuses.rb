# frozen_string_literal: true

# 04 R2タスク4: 案件ステータスのDB管理化（Laravel移行元は database/migrations/
# 2026_06_12_000003_create_order_statuses_table.php。codeはorders.statusに格納される実値）。
class CreateOrderStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :order_statuses, id: :uuid do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.boolean :is_system, null: false, default: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :order_statuses, :code, unique: true
    add_index :order_statuses, %i[is_active sort_order]

    add_foreign_key :order_statuses, :users, column: :created_by_id
    add_foreign_key :order_statuses, :users, column: :updated_by_id
  end
end
