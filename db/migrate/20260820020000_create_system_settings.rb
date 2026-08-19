# システム設定（R6-3・2026-08-20 CEO決定）。brige-crmはシングルテナントのため、ftlogのような
# 「組織ごとの設定」テーブルではなく、アプリ全体で常に1行のみが存在するシングルトン設定として持つ。
# 値はモデル層（SystemSetting.current）で1行に強制する（DB制約は課さない。ip_allowlist_entries等の
# 既存シングルトン相当が無い＝先例が無いため、TracksUser/Auditableと同じ「モデルで守る」方針に揃えた）。
#
# 初期対象は「問い合わせ添付ファイルの上限」（従来 InquiryMessage の class 定数だった値。
# app/models/inquiry_message.rb 参照）。カラムの default 値は移行前の定数値と同じにして、
# 移行前後で挙動が変わらないようにしている。
class CreateSystemSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :system_settings, id: :uuid do |t|
      t.integer :inquiry_attachment_max_count, null: false, default: 5
      t.integer :inquiry_attachment_max_size_mb, null: false, default: 50

      t.uuid :created_by_id
      t.uuid :updated_by_id

      t.timestamps null: false
    end

    add_foreign_key :system_settings, :users, column: :created_by_id
    add_foreign_key :system_settings, :users, column: :updated_by_id
  end
end
