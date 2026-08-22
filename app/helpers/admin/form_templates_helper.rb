# フォームビルダー（Admin::FormTemplates）の非エンジニア向けUI刷新。app/models/form_field.rb の
# FIELD_TYPES / TIERS 定数（英語のenum値。バリデーションの正）は変更せず、ここでは表示文言のみを
# 対応づける。値の追加・変更は引き続き form_field.rb 側で行う。
module Admin::FormTemplatesHelper
  FIELD_TYPE_LABELS = {
    "text" => "テキスト（1行）",
    "textarea" => "長文テキスト",
    "date" => "日付",
    "integer" => "数値",
    "boolean" => "はい・いいえ",
    "select" => "選択式（1つ選択）",
    "checkbox_group" => "複数選択（チェックボックス）"
  }.freeze

  TIER_LABELS = {
    "sales_representative" => "営業担当者",
    "agency" => "代理店",
    "admin" => "管理者"
  }.freeze

  # 検証ルール種別（validation_rules）のプルダウン選択肢。現状は最大文字数（max_length。
  # Form::DynamicFormValidator#length_errors が解釈する唯一のキー）のみ。将来ルール種別が
  # 増えたときはここへ1行追加するだけで、行入力UI（validation-rule-list Stimulusコントローラ）と
  # プルダウンの両方に反映される。
  VALIDATION_RULE_TYPE_OPTIONS = [
    [ "最大文字数", "max_length" ]
  ].freeze

  def form_field_type_options
    FormField::FIELD_TYPES.map { |type| [ FIELD_TYPE_LABELS.fetch(type, type), type ] }
  end

  def form_field_tier_label(tier)
    TIER_LABELS.fetch(tier, tier)
  end
end
