# frozen_string_literal: true

# 04 R2タスク3（Laravel移行元: database/migrations/2026_05_13_000010_create_products_table.php）。
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, id: :uuid do |t|
      t.string :name, limit: 100, null: false
      t.string :code, limit: 20, null: false
      t.text :description
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :products, :code, unique: true
    add_index :products, :is_active

    add_foreign_key :products, :users, column: :created_by_id
    add_foreign_key :products, :users, column: :updated_by_id
  end
end
