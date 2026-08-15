# frozen_string_literal: true

# 04 R2タスク6（Laravel移行元: database/migrations/
# 2026_05_28_000003_create_inquiry_messages_and_production_companies_table.php の production_companies 部分。
# inquiry_messages / inquiry_message_production_companies はR4（問い合わせ）のスコープのためここでは作らない）。
class CreateProductionCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :production_companies, id: :uuid do |t|
      t.string :name, limit: 100, null: false
      t.string :contact_name, limit: 50
      t.string :email, limit: 255
      t.string :phone, limit: 20
      t.text :notes
      t.boolean :is_active, null: false, default: true

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :production_companies, :is_active

    add_foreign_key :production_companies, :users, column: :created_by_id
    add_foreign_key :production_companies, :users, column: :updated_by_id
  end
end
