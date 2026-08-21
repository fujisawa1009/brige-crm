require "rails_helper"

# AILINK商材（2026-08-21 CEO指示・浅賀確認用_選択フォーム要件整理.xlsx P2〜P9）の申込フォーム
# テンプレート投入。冪等性・件数・ホワイトリスト適合・マスタ由来選択肢を検証する。
RSpec.describe AilinkFormTemplateSeeder do
  # 7ステップ（事前入力/契約者/店舗施設/支払方法/GBP登録/架電日時/アカウント情報）・108フィールド
  EXPECTED_FIELD_COUNT = described_class::STEPS.sum { |s| s[:fields].size }

  it "Product/ProductInitialFee/FormTemplate/FormStep/FormField/OptionGroupを冪等に作成する" do
    expect { described_class.call }.to change(FormField, :count).by(EXPECTED_FIELD_COUNT)
      .and change(OptionGroup, :count).by(described_class::OPTION_GROUPS.size)
      .and change(ProductInitialFee, :count).by(5)

    product = Product.find_by!(code: "AILINK")
    expect(product.form_template.form_steps.count).to eq(7)
    expect(EXPECTED_FIELD_COUNT).to eq(108)

    expect { described_class.call }.not_to change(FormField, :count) # 2回目は増えない
  end

  it "全フィールドがtarget_columnホワイトリストを満たす" do
    described_class.call

    template = Product.find_by!(code: "AILINK").form_template
    expect(template.form_steps.sum { |s| s.form_fields.count }).to eq(EXPECTED_FIELD_COUNT)
    template.form_steps.each do |step|
      step.form_fields.each do |field|
        allowed = FormField.allowed_target_columns_for(field.target_table)
        expect(allowed).to include(field.target_column),
          "#{field.field_key}: #{field.target_column} は#{field.target_table}のホワイトリスト外"
      end
    end
  end

  it "初期費用（P2）の選択肢はAILINKのProductInitialFeeマスタから複製される" do
    described_class.call

    product = Product.find_by!(code: "AILINK")
    field = FormField.find_by!(field_key: "product_initial_fee")
    expect(field.target_column).to eq("product_initial_fee_id")

    expected = product.product_initial_fees.active.order(:sort_order).pluck(:id, :name).map { |id, name| [ id.to_s, name ] }
    expect(field.input_options["choices"]).to eq(expected)
    expect(expected.map(&:last)).to eq([ "0円", "30,000円", "50,000円", "100,000円", "150,000円" ])
  end

  it "P9必須項目（Instagram ID/PASS・システムアカウントPASS等）が必須として投入される" do
    described_class.call

    template = Product.find_by!(code: "AILINK").form_template
    required_keys = FormField.joins(:form_step)
                             .where(form_steps: { form_template_id: template.id }, required: true)
                             .pluck(:field_key)
    expect(required_keys).to include(
      "instagram_id", "instagram_pass", "system_account_pass",
      "has_line", "has_facebook", "has_facebook_page",
      "inventory_type", "product_initial_fee", "discount_option", "customer_email"
    )
  end

  it "割引オプション（P2 オプション②）はorders.discount_optionへ3値のselectで投入される" do
    described_class.call

    field = FormField.find_by!(field_key: "discount_option")
    expect(field.target_table).to eq("order")
    expect(field.target_column).to eq("discount_option")
    expect(field.input_options["choices"].map(&:first)).to eq(
      [ "割引なし", "長期割引（税込11,000円）", "長期割引（税込22,000円）" ]
    )
  end

  it "checkbox_groupのGBP属性はstring(100)あふれ防止のmax_lengthを持つ" do
    described_class.call

    field = FormField.find_by!(field_key: "gbp_attribute_8")
    expect(field.field_type).to eq("checkbox_group")
    expect(field.validation_rules["max_length"]).to eq(100)
  end
end
