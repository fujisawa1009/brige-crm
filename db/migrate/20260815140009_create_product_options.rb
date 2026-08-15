# frozen_string_literal: true

# 04 R2タスク3（Laravel移行元: database/migrations/2026_05_26_000002_create_product_options_table.php）。
class CreateProductOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :product_options, id: :uuid do |t|
      t.uuid :product_id, null: false
      t.string :name, limit: 100, null: false
      t.text :description
      t.integer :monthly_fee
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :product_options, %i[product_id sort_order]
    add_index :product_options, :is_active

    add_foreign_key :product_options, :products, on_delete: :cascade
    add_foreign_key :product_options, :users, column: :created_by_id
    add_foreign_key :product_options, :users, column: :updated_by_id
  end
end
