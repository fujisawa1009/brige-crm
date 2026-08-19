# R6-4: 返信メッセージがどのテンプレートから作られたかのメタ情報（テンプレート由来かどうかの記録）。
# ftlogの`IssueTemplate`は「テンプレート未選択でも新規作成できてしまう」（UI動線のみで強制・URL直叩き
# でバイパス可能）という弱点があった。brige-crmでは全返信にテンプレート選択を必須化はしない
# （自由記述の返信も業務上必要なため）が、"このIDのテンプレートを使った"という申告自体は
# サーバー側で検証する: inquiry_template_id が指定された場合は実在するInquiryTemplateを
# 参照していることをモデルバリデーション（InquiryMessage#inquiry_template presence validation）で
# 必須化し、存在しないIDを指定した申告は保存させない（FK制約も併せて多層防御にする）。
class AddInquiryTemplateToInquiryMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :inquiry_messages, :inquiry_template_id, :uuid

    add_index :inquiry_messages, :inquiry_template_id

    add_foreign_key :inquiry_messages, :inquiry_templates, column: :inquiry_template_id, on_delete: :nullify
  end
end
