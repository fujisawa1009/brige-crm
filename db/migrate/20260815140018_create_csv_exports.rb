# frozen_string_literal: true

# 04 R2タスク7: CSV非同期エクスポート基盤（UserCsvImportJob=CSVインポートと対になる、CSVエクスポート側）。
# ActiveStorageは導入せず、生成したCSV本文をfile_data(text)にそのまま保存する軽量実装
# （エクスポート対象は数千件規模の管理データであり、大容量ファイルストレージが必要になるまでは
# DB保存で十分。過剰設計回避）。
class CreateCsvExports < ActiveRecord::Migration[8.1]
  def change
    create_table :csv_exports, id: :uuid do |t|
      # "Customer" / "Order" 等、エクスポート対象のモデル名。
      t.string :resource_type, null: false
      t.string :status, null: false, default: "pending" # pending / completed / failed
      t.uuid :requested_by_id, null: false
      t.integer :row_count
      t.text :file_data
      t.text :error_message

      t.timestamps
    end

    add_index :csv_exports, :requested_by_id
    add_index :csv_exports, :status

    add_foreign_key :csv_exports, :users, column: :requested_by_id
  end
end
