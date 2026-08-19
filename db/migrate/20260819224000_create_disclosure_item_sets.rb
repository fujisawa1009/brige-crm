# frozen_string_literal: true

# R5-13（contract-confirmation-docs.md §3-1）: 重要事項説明チェックの項目マスタを版管理する。
# 重説項目は将来変更されるため「どの版で説明したか」をdisclosure_checksから固定参照できるようにし、
# 後から項目が変わっても過去の証跡が壊れないようにする。
class CreateDisclosureItemSets < ActiveRecord::Migration[8.1]
  def change
    create_table :disclosure_item_sets, id: :uuid do |t|
      t.integer :version, null: false
      t.date    :effective_from, null: false
      t.uuid    :created_by_id

      t.timestamps
    end

    add_index :disclosure_item_sets, :version, unique: true

    add_foreign_key :disclosure_item_sets, :users, column: :created_by_id
  end
end
