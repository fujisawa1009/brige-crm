# 動的マルチステップの1画面分（04 R3タスク3・4）。step_numberがそのまま表示順・ルーティング上の
# ステップ番号を兼ねる（Laravel現行 routes/form.php の step/{n} を踏襲）。
class CreateFormSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :form_steps, id: :uuid do |t|
      t.uuid :form_template_id, null: false
      t.integer :step_number, null: false
      t.string :name, null: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :form_steps, %i[form_template_id step_number], unique: true

    add_foreign_key :form_steps, :form_templates, on_delete: :cascade
    add_foreign_key :form_steps, :users, column: :created_by_id
    add_foreign_key :form_steps, :users, column: :updated_by_id
  end
end
