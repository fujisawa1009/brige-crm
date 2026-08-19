# frozen_string_literal: true

# R5-5b（master-data-design-policy.md §5-3）: payment_methodを選択肢マスタ(OptionGroup)から
# 専用テーブルへ昇格。D-P12①の3択分岐（口振/クレカ/おまとめ）が値を見て処理を変えるため、
# is_system保護とコード定数が必要（OptionGroupには無い）。order_statuses/customer_statusesと同型。
class CreatePaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_methods, id: :uuid do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.boolean :is_system, null: false, default: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :payment_methods, :code, unique: true
    add_index :payment_methods, %i[is_active sort_order]

    add_foreign_key :payment_methods, :users, column: :created_by_id
    add_foreign_key :payment_methods, :users, column: :updated_by_id
  end
end
