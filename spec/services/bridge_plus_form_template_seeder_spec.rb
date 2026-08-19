require "rails_helper"

# 04 R3残（form-template-mapping.md §9-2 #1）: BRIDGE_PLUS申込フォームのフィールド＋OptionGroup投入の
# 冪等性・件数・ホワイトリスト適合を検証する。個別フィールドの網羅比較は §9-3 の67件表に依拠する。
#
# 件数の内訳: form-template-mapping.md §2 の67件 ＋ Q-45（2026-08-18浅賀MTG・2026-08-19 CEO決定）で
# 追加した Instagram ID/パスワードの2件（必須入力）＝ 計69件・8ステップ。
RSpec.describe BridgePlusFormTemplateSeeder do
  it "Product/FormTemplate/FormStep/FormField/OptionGroupを冪等に作成する" do
    expect { described_class.call }.to change(FormField, :count).by(69)
      .and change(OptionGroup, :count).by(8)

    product = Product.find_by!(code: "BRIDGE_PLUS")
    expect(product.form_template.form_steps.count).to eq(8)

    expect { described_class.call }.not_to change(FormField, :count) # 2回目は増えない
  end

  it "Q-45: Instagram ID/パスワードが必須入力フィールドとして投入される" do
    described_class.call

    template = Product.find_by!(code: "BRIDGE_PLUS").form_template
    required = FormField.joins(:form_step)
                        .where(form_steps: { form_template_id: template.id }, required: true)
    expect(required.pluck(:field_key)).to match_array(%w[instagram_id instagram_pass])
    expect(required.pluck(:target_column)).to match_array(%w[instagram_id instagram_pass])
  end

  it "全フィールドがtarget_columnホワイトリストを満たす（FormField保存時のバリデーションで担保）" do
    described_class.call

    template = Product.find_by!(code: "BRIDGE_PLUS").form_template
    expect(template.form_steps.sum { |s| s.form_fields.count }).to eq(69)
    template.form_steps.each do |step|
      step.form_fields.each do |field|
        allowed = FormField.allowed_target_columns_for(field.target_table)
        expect(allowed).to include(field.target_column),
          "#{field.field_key}: #{field.target_column} は#{field.target_table}のホワイトリスト外"
      end
    end
  end

  it "select型フィールドはinput_options.choicesを持つ" do
    described_class.call

    prefecture_field = FormField.find_by!(field_key: "prefecture")
    expect(prefecture_field.input_options["choices"].size).to eq(47)

    yes_no_field = FormField.find_by!(field_key: "plus_applied")
    expect(yes_no_field.input_options["choices"]).to eq([ [ "はい", "はい" ], [ "いいえ", "いいえ" ] ])
  end

  it "OptionGroup(prefecture)は47都道府県のOptionValueを持つ" do
    described_class.call

    group = OptionGroup.find_by!(key: "prefecture")
    expect(group.option_values.count).to eq(47)
  end
end
