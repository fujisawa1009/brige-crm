# P2拡張後仕様のフィールド定義（04 R3タスク3。development-plan.mdのtarget_table/target_column/
# editable_by_tier/lock_after_statusをそのまま初期スキーマに採用）。
#
# target_table/target_column: このフィールドの回答をどのモデル・カラムへ書き込むか
#   （Form::ApplicationSubmissionServiceが参照。target_column は当該モデルの通常カラムだけでなく、
#   has_many :through の集合idsライター（例: Order#product_option_ids=）も指せる汎用設計にしている。
#   これにより「選択オプション（jasmin_order_options相当）」も特別扱いなしで同じ仕組みに乗る）。
# editable_by_tier: 誰がこのフィールドを編集できるか（string配列。R3時点ではsales_representativeのみ
#   実際にフォームを操作するが、R4/R5で代理店・管理者による再編集を追加する余地を残す）。
# lock_after_status: Orderが到達すると編集不可にする閾ステータス（order_statuses.code）。R3の新規申込
#   フローでは同一トランザクション内でOrderを新規作成するため到達判定の対象外だが、R4/R5の
#   再編集フローに備えてFormField側にデータとして持たせておく（FormField#locked_for?参照）。
class CreateFormFields < ActiveRecord::Migration[8.1]
  def change
    create_table :form_fields, id: :uuid do |t|
      t.uuid :form_step_id, null: false
      t.string :field_key, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.string :target_table, null: false
      t.string :target_column
      t.boolean :required, null: false, default: false
      t.integer :sort_order, null: false, default: 0
      t.string :editable_by_tier, array: true, null: false, default: [ "sales_representative" ]
      t.string :lock_after_status
      t.jsonb :input_options, null: false, default: {}
      t.jsonb :validation_rules, null: false, default: {}

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :form_fields, %i[form_step_id field_key], unique: true
    add_index :form_fields, :editable_by_tier, using: :gin

    add_foreign_key :form_fields, :form_steps, on_delete: :cascade
    add_foreign_key :form_fields, :users, column: :created_by_id
    add_foreign_key :form_fields, :users, column: :updated_by_id
  end
end
