# 商材選択に続くプラン・初期費用選択（04 R3タスク5。Laravel現行 step1Store の
# plan_id/product_initial_fee_id/hearing_content相当）。option_ids（複数選択）は正規化テーブルを
# 増やさず form_data(jsonb) 側に "option_ids" キーで暫定保持し、完了時に order_options へ展開する
# （Application#option_ids参照）。plan/初期費用はOrder生成時にそのまま引き渡す実カラムのためFKを持つ。
class AddPlanSelectionToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :plan_id, :uuid
    add_column :applications, :product_initial_fee_id, :uuid
    add_column :applications, :hearing_content, :text

    add_index :applications, :plan_id
    add_index :applications, :product_initial_fee_id

    add_foreign_key :applications, :plans, on_delete: :nullify
    add_foreign_key :applications, :product_initial_fees, on_delete: :nullify
  end
end
