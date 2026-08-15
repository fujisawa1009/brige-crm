# frozen_string_literal: true

# 販売許可（Product×AgencyGroup中間）。Laravel移行元:
# database/migrations/2026_06_04_000001_create_agency_group_products_table.php。
# Laravel側はservice_type(Bridge/BridgePlus)からの移行データ投入も行っていたが、brige-crmは
# 単一テナントの新規スキーマのためデータ移行は行わない（R7のETL対象。空テーブルから開始する）。
class CreateAgencyGroupProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :agency_group_products, id: :uuid do |t|
      t.uuid :agency_group_id, null: false
      t.uuid :product_id, null: false

      t.timestamps
    end

    add_index :agency_group_products, %i[agency_group_id product_id], unique: true, name: "index_agency_group_products_on_group_and_product"
    add_index :agency_group_products, :product_id

    add_foreign_key :agency_group_products, :agency_groups, on_delete: :cascade
    add_foreign_key :agency_group_products, :products, on_delete: :cascade
  end
end
