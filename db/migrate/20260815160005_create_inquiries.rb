# 問い合わせ（04 R4タスク1・2。Column.md参照。Laravel Inquiry.php移植＋決定D-11掲示板統合拡張を
# 初期スキーマから織り込む＝enumを経由せず最初からステータスマスタ参照で作る）。
#
# order_id は必須FK（Laravel現行 jasmin_order_id 踏襲。ER図「JasminOrder ─* Inquiry」）。
# category は元のInquiry::CATEGORIES 4値（後確/制作対応/検収コール/アフター問合せ）をそのまま使う
# （掲示板4種の呼称と一致させておくとR7移行時のマッピングが素直になる。09-implementation-planの
# 段階案=新規はinquiries・過去42万件は別テーブルという棲み分けとも整合する）。
#
# アフター固有列（board-implementation-options.md §2-2「アフター固有」行）: カテゴリ1-3(緊急度/種別/領域)・
# 受電窓口・初回/次回対応者。after_ prefixを付け、category="アフター問合せ"以外では未使用（nullable）。
class CreateInquiries < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiries, id: :uuid do |t|
      t.string :inquiry_number, null: false
      t.uuid :order_id, null: false
      t.string :title
      t.string :category, null: false
      t.string :status, null: false
      t.boolean :is_visible_to_agent, null: false, default: true

      # アフター掲示板固有（board-implementation-options.md §1表の「カテゴリ1-3・受電窓口・
      # 初回/次回対応者」）。現行は自由入力のためstring、選択肢の統制はR6以降で検討。
      t.string :after_urgency
      t.string :after_type
      t.string :after_area
      t.string :reception_channel
      t.string :first_responder_name
      t.string :next_responder_name

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :inquiries, :inquiry_number, unique: true
    add_index :inquiries, :order_id
    add_index :inquiries, %i[category status]

    add_foreign_key :inquiries, :orders, on_delete: :restrict
    add_foreign_key :inquiries, :users, column: :created_by_id
    add_foreign_key :inquiries, :users, column: :updated_by_id
  end
end
