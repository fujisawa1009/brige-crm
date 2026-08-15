# 申込トランザクション（04 R3タスク5。Laravel移行元 Application モデル）。token(64桁)で
# 営業担当者のセッションと紐づけつつ、ステップをまたいだ回答をform_data(jsonb)に蓄積し、
# 完了時にForm::ApplicationSubmissionServiceが1トランザクションでCustomer/Store/Order等を生成する。
#
# customer_id/store_id/order_idは完了後にのみ埋まる（申込途中は全てnull）。form_templateは
# product経由（product.form_template）で解決するため、versioning機構が無い現段階では冗長な
# form_template_idを持たせない。
class CreateApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :applications, id: :uuid do |t|
      t.string :token, null: false, limit: 64
      t.uuid :sales_representative_id, null: false
      t.uuid :agency_id, null: false
      t.uuid :product_id, null: false
      t.uuid :customer_id
      t.uuid :store_id
      t.uuid :order_id
      t.string :status, null: false, default: "in_progress"
      t.integer :current_step_number, null: false, default: 1
      t.jsonb :form_data, null: false, default: {}
      t.datetime :completed_at

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :applications, :token, unique: true
    add_index :applications, :sales_representative_id
    add_index :applications, :status

    add_foreign_key :applications, :sales_representatives, on_delete: :restrict
    add_foreign_key :applications, :agencies, on_delete: :restrict
    add_foreign_key :applications, :products, on_delete: :restrict
    add_foreign_key :applications, :customers, on_delete: :nullify
    add_foreign_key :applications, :stores, on_delete: :nullify
    add_foreign_key :applications, :orders, on_delete: :nullify
    add_foreign_key :applications, :users, column: :created_by_id
    add_foreign_key :applications, :users, column: :updated_by_id
  end
end
