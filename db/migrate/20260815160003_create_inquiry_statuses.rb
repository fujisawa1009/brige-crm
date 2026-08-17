# 問い合わせステータスマスタ（04 R4タスク2・決定D-11・board-implementation-options.md §2-2）。
#
# 掲示板統合前のInquiryは固定4値（未対応/対応中/対応済み/クローズ）のDB enumだったが、
# 掲示板4種（後確/制作対応/検収コール/アフター問合せ）はそれぞれ独立したステータス集合を持つ
# （8値/7値/6値/4値。board-implementation-options.md §1の表）。enumのままでは表現不可のため、
# CustomerStatus/OrderStatus（04 R2タスク4）と同じ「DB管理マスタ化」パターンを踏襲しつつ、
# code の一意性を category 単位にスコープする点だけが異なる（同じcodeでも掲示板種別が違えば別行）。
class CreateInquiryStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiry_statuses, id: :uuid do |t|
      t.string :category, null: false
      t.string :code, null: false
      t.string :label, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.boolean :is_system, null: false, default: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :inquiry_statuses, %i[category code], unique: true
    add_index :inquiry_statuses, %i[category is_active sort_order], name: "index_inquiry_statuses_on_category_active_order"

    add_foreign_key :inquiry_statuses, :users, column: :created_by_id
    add_foreign_key :inquiry_statuses, :users, column: :updated_by_id
  end
end
