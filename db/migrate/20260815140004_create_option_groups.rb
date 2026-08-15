# frozen_string_literal: true

# 04 R2タスク4（Laravel移行元: database/migrations/2026_05_13_000004_create_option_groups_table.php）。
class CreateOptionGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :option_groups, id: :uuid do |t|
      t.string :key, null: false
      t.string :label, null: false
      t.text :description
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :option_groups, :key, unique: true
    add_index :option_groups, :is_active
    add_index :option_groups, :sort_order

    add_foreign_key :option_groups, :users, column: :created_by_id
    add_foreign_key :option_groups, :users, column: :updated_by_id
  end
end
