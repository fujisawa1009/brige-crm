# 種別×ステータス→宛先ルーティングマスタ（04 R4タスク2・決定D-11）。
#
# board-implementation-options.md §1「業務上の性格の違い」: 後確・制作・検収コールの3種は
# 「ステータス選択＝宛先ルーティング」（05§5-1の転送先マトリクス）そのものが業務ロジック。
# 1つの category×status_code の組に複数の宛先グループを割り当てられるよう
# （例: 「営業部対応依頼」→営業担当者グループ＋代理店グループの2系統に同時通知）1行=1宛先とし、
# 同じ組に複数行を許可する（recipient_group_id込みでユニーク制約）。
class CreateInquiryRecipientRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiry_recipient_routes, id: :uuid do |t|
      t.string :category, null: false
      t.string :status_code, null: false
      t.uuid :recipient_group_id, null: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :inquiry_recipient_routes, %i[category status_code], name: "index_inquiry_recipient_routes_on_category_status"
    add_index :inquiry_recipient_routes, %i[category status_code recipient_group_id],
              unique: true, name: "index_inquiry_recipient_routes_on_category_status_group"

    add_foreign_key :inquiry_recipient_routes, :recipient_groups, on_delete: :cascade
    add_foreign_key :inquiry_recipient_routes, :users, column: :created_by_id
    add_foreign_key :inquiry_recipient_routes, :users, column: :updated_by_id
  end
end
