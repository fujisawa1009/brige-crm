# 申込フォーム定義（04 R3タスク3）。P2拡張後仕様（target_table/target_column/editable_by_tier/
# lock_after_status）を初期実装からFormFieldに持たせる方針のため、FormTemplate自体はProductとの
# 1-1関係とメタ情報（有効/無効）だけを持つ薄いモデルにする（03§5「Product 1─1 FormTemplate」）。
class CreateFormTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :form_templates, id: :uuid do |t|
      t.uuid :product_id, null: false
      t.string :name, null: false
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :form_templates, :product_id, unique: true # Product 1-1 FormTemplate

    add_foreign_key :form_templates, :products, on_delete: :cascade
    add_foreign_key :form_templates, :users, column: :created_by_id
    add_foreign_key :form_templates, :users, column: :updated_by_id
  end
end
