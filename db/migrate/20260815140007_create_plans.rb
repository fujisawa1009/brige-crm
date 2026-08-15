# frozen_string_literal: true

# 04 R2タスク3（Laravel移行元: database/migrations/2026_05_13_000011_create_plans_table.php）。
class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans, id: :uuid do |t|
      t.uuid :product_id, null: false
      t.string :name, limit: 100, null: false
      t.string :code, limit: 20
      t.integer :monthly_fee
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :plans, :product_id
    add_index :plans, :is_active

    add_foreign_key :plans, :products, on_delete: :restrict
    add_foreign_key :plans, :users, column: :created_by_id
    add_foreign_key :plans, :users, column: :updated_by_id
  end
end
