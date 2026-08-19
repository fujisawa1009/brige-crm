# 問い合わせ返信テンプレート（R6-4。legacy-research/13-faq-templates.md F-1〜F-4 の実装。
# NotificationTemplate（一斉通知/共通用）とはカテゴリ軸が異なる別マスタとして新設する
# （FAQ 12カテゴリは "ログイン情報関連" 等の外部システム操作FAQ分類であり、NotificationTemplateの
# template_type: inquiry区分に無理にカテゴリ列を足すと一斉通知側の語彙と衝突するため）。
class CreateInquiryTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiry_templates, id: :uuid do |t|
      # FAQ 12カテゴリ（InquiryTemplate::CATEGORIESでモデル側に列挙）。マスタテーブル化はせず
      # 文字列＋モデルのinclusionバリデーションで担保する（InquiryStatus等の別軸マスタと違い、
      # 運用中にカテゴリ集合が動く想定が薄いため。将来必要になれば別マスタ化を検討）。
      t.string :category, null: false
      t.string :name, null: false
      t.text :body, null: false

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :inquiry_templates, :category

    add_foreign_key :inquiry_templates, :users, column: :created_by_id
    add_foreign_key :inquiry_templates, :users, column: :updated_by_id
  end
end
