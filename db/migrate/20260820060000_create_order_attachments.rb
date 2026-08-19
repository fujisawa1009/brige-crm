# R6-8 ファイル管理基盤（04-implementation-plan.md R6-8。2026-08-20 CEO決定）。
# Order配下の汎用添付ファイル基盤。ftlogのFolderViewer相当（社内限定公開/顧客公開の一元管理）を
# 「1ファイル=1可視性フラグ」に簡略化して採用する。将来のR5-11（契約書PDF）・重説チェック・
# 手書き署名の添付先として使えることを狙うが、本マイグレーション自体は決済状態機械
# （PaymentTransaction等）・契約ワークフロー状態機械（orders.contract_status等）には一切触れない。
#
# ファイル本体はActive Storageのhas_one_attachedで持つ（専用テーブル不要。active_storage_*は
# 20260815150007で追加済み）。file_type はContractPDF等の種別タグ（自由記述。今回は「中身が
# 契約書かどうかは問わない」汎用基盤のためマスタ化・enum化はしない）。
#
# is_visible_to_customer のデフォルトはfalse（Inquiry.is_visible_to_customerのデフォルトtrueとは
# 意図的に逆）: Inquiryは「やり取りの可視性」で既定公開・必要な投稿だけ社内限定にする運用だが、
# OrderAttachmentは契約書ドラフトや内部資料等、アップロード直後は社内限定が安全側のデフォルトと
# 判断した（顧客公開はスタッフが明示的にオプトインする設計）。
class CreateOrderAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :order_attachments, id: :uuid do |t|
      t.uuid :order_id, null: false
      t.string :file_type, limit: 50
      t.boolean :is_visible_to_customer, null: false, default: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :order_attachments, :order_id

    add_foreign_key :order_attachments, :orders, on_delete: :cascade
    add_foreign_key :order_attachments, :users, column: :created_by_id
    add_foreign_key :order_attachments, :users, column: :updated_by_id
  end
end
