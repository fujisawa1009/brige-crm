# frozen_string_literal: true

# 04 R2タスク6（Laravel移行元: database/migrations/2026_05_28_000004_create_sales_materials_table.php）。
# category は営業資料カテゴリ6種（SalesMaterial::CATEGORIES）。ファイル実体はActiveStorageを
# 新規導入せず、Laravel踏襲でfile_path(VARCHAR)に保存先パス/URLを持たせるだけに留める
# （過剰設計回避。実ファイルアップロードUIの要否はR2完了条件に含まれていないため後続フェーズ判断）。
class CreateSalesMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :sales_materials, id: :uuid do |t|
      t.string :title, limit: 255, null: false
      t.string :category, limit: 50
      t.text :description
      t.string :file_path, limit: 500, null: false
      t.string :original_file_name, limit: 255, null: false
      t.bigint :file_size, null: false
      t.string :mime_type, limit: 100, null: false
      t.boolean :is_published, null: false, default: false
      t.integer :sort_order, null: false, default: 0

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :sales_materials, :is_published
    add_index :sales_materials, :category

    add_foreign_key :sales_materials, :users, column: :created_by_id
    add_foreign_key :sales_materials, :users, column: :updated_by_id
  end
end
