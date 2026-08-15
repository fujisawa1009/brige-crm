# frozen_string_literal: true

# 04 R1で先送りされていた販売許可（Product×Agency中間テーブル）をR2でProductと同時に実装する
# （04 R1本文「販売許可（Product×Agency/AgencyGroup 中間）はR2でProductと同時に」）。
# Laravel移行元: database/migrations/2026_05_13_000012_create_agency_products_table.php。
class CreateAgencyProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :agency_products, id: :uuid do |t|
      t.uuid :agency_id, null: false
      t.uuid :product_id, null: false

      t.timestamps
    end

    add_index :agency_products, %i[agency_id product_id], unique: true
    add_index :agency_products, :product_id

    add_foreign_key :agency_products, :agencies, on_delete: :cascade
    add_foreign_key :agency_products, :products, on_delete: :cascade
  end
end
