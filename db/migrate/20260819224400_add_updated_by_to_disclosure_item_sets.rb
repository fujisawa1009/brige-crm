# frozen_string_literal: true

# DisclosureItemSetがTracksUser（created_by_id/updated_by_id両方必須）をincludeするための追加列。
# 当初のcontract-confirmation-docs.md §3-1案はcreated_by_idのみだったが、他モデルと同じ
# 作成者/更新者追跡の慣習（TracksUser concern）に揃える。
class AddUpdatedByToDisclosureItemSets < ActiveRecord::Migration[8.1]
  def change
    add_column :disclosure_item_sets, :updated_by_id, :uuid
    add_foreign_key :disclosure_item_sets, :users, column: :updated_by_id
  end
end
