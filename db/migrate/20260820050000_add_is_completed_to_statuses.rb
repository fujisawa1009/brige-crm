# R6-6（完了済み含む検索）: Order・Inquiry一覧の「既定で完了/終了系ステータスを除外」判定を
# OrderStatus/InquiryStatusマスタのフラグで表現する。ハードコードのコード列挙をFilter側に持たせると
# ステータス追加のたびにコード側の修正が要る（ftlogで社内/ポータルにロジックが重複していた反省と
# 同種の保守コスト）ため、既存のステータスマスタ編集画面（Admin::OrderStatusesController等）から
# 運用時に切り替えられるようフラグ化する。
class AddIsCompletedToStatuses < ActiveRecord::Migration[8.1]
  def change
    add_column :order_statuses, :is_completed, :boolean, default: false, null: false
    add_column :inquiry_statuses, :is_completed, :boolean, default: false, null: false
  end
end
