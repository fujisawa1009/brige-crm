require "rails_helper"

# 04 R3残（form-template-mapping.md §9-2 #1）: BRIDGE_PLUS申込フォーム67フィールド＋OptionGroup投入の
# 冪等性・件数・ホワイトリスト適合を検証する。個別フィールドの網羅比較は §9-3 の67件表に依拠する。
RSpec.describe BridgePlusFormTemplateSeeder do
  it "Product/FormTemplate/FormStep/FormField/OptionGroupを冪等に作成する" do
    expect { described_class.call }.to change(FormField, :count).by(67)
      .and change(OptionGroup, :count).by(8)

    product = Product.find_by!(code: "BRIDGE_PLUS")
    expect(product.form_template.form_steps.count).to eq(7)

    expect { described_class.call }.not_to change(FormField, :count) # 2回目は増えない
  end

  it "全フィールドがtarget_columnホワイトリストを満たす（FormField保存時のバリデーションで担保）" do
    described_class.call

    template = Product.find_by!(code: "BRIDGE_PLUS").form_template
    expect(template.form_steps.sum { |s| s.form_fields.count }).to eq(67)
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
