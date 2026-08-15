# frozen_string_literal: true

# 04 R2タスク4（Laravel移行元: database/migrations/2026_05_13_000005_create_option_values_table.php）。
# parent_id自己参照でツリー構造を表現する。CTO判断（過剰設計回避）: closure_tree/ancestry等の
# 専用gemは導入しない。深さの上限が「大分類・中分類」程度（Laravel側の実データもdepth<=1）で
# 再帰CTEや高速な祖先/子孫クエリが必要なほどの階層深度・検索要件が無いため、
# belongs_to :parent / has_many :children のシンプルな自己参照で十分（Laravel実装もgem不使用の素の自己参照）。
class CreateOptionValues < ActiveRecord::Migration[8.1]
  def change
    create_table :option_values, id: :uuid do |t|
      t.uuid :option_group_id, null: false
      t.uuid :parent_id
      t.string :value, null: false
      t.string :label, null: false
      t.integer :depth, null: false, default: 0
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :option_values, %i[option_group_id value], unique: true
    add_index :option_values, :option_group_id
    add_index :option_values, :parent_id
    add_index :option_values, :is_active

    add_foreign_key :option_values, :option_groups, on_delete: :cascade
    add_foreign_key :option_values, :option_values, column: :parent_id, on_delete: :cascade
    add_foreign_key :option_values, :users, column: :created_by_id
    add_foreign_key :option_values, :users, column: :updated_by_id
  end
end
