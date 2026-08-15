# Order⇄ProductOption中間テーブル（jasmin_order_options相当。04 R2の申し送り「R3実装時に追加する」を
# ここで解消する）。申込トランザクションではForm::ApplicationSubmissionServiceがOrder#product_option_ids=
# （has_many :through が自動生成するcollection idsライター）経由でFormField(target_table: "order",
# target_column: "product_option_ids")のchecked値をそのまま書き込む。
class CreateOrderOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :order_options, id: :uuid do |t|
      t.uuid :order_id, null: false
      t.uuid :product_option_id, null: false

      t.timestamps
    end

    add_index :order_options, %i[order_id product_option_id], unique: true
    add_index :order_options, :product_option_id

    add_foreign_key :order_options, :orders, on_delete: :cascade
    add_foreign_key :order_options, :product_options, on_delete: :restrict
  end
end
