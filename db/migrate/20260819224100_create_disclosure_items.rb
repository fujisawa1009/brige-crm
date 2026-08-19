# frozen_string_literal: true

# R5-13（contract-confirmation-docs.md §3-1）: 重説項目マスタ（項目セットに属する）。
class CreateDisclosureItems < ActiveRecord::Migration[8.1]
  def change
    create_table :disclosure_items, id: :uuid do |t|
      t.uuid    :disclosure_item_set_id, null: false
      t.integer :sort_order, null: false, default: 0
      t.string  :title, null: false
      t.text    :body, null: false
      t.boolean :is_required, null: false, default: true

      t.timestamps
    end

    add_index :disclosure_items, :disclosure_item_set_id

    add_foreign_key :disclosure_items, :disclosure_item_sets
  end
end
