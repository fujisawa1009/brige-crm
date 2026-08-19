# frozen_string_literal: true

# R5-13（contract-confirmation-docs.md §3-1）: 重説チェックの項目ごとの結果明細。
class CreateDisclosureCheckItems < ActiveRecord::Migration[8.1]
  def change
    create_table :disclosure_check_items, id: :uuid do |t|
      t.uuid     :disclosure_check_id, null: false
      t.uuid     :disclosure_item_id, null: false
      t.boolean  :checked, null: false, default: false
      t.datetime :checked_at

      t.timestamps
    end

    add_index :disclosure_check_items, :disclosure_check_id
    add_index :disclosure_check_items, [ :disclosure_check_id, :disclosure_item_id ], unique: true,
              name: "index_disclosure_check_items_on_check_and_item"

    add_foreign_key :disclosure_check_items, :disclosure_checks
    add_foreign_key :disclosure_check_items, :disclosure_items
  end
end
