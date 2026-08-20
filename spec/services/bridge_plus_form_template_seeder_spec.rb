require "rails_helper"

# 04 R3残（form-template-mapping.md §9-2 #1）: BRIDGE_PLUS申込フォームのフィールド＋OptionGroup投入の
# 冪等性・件数・ホワイトリスト適合を検証する。個別フィールドの網羅比較は §9-3 の67件表に依拠する。
#
# 件数の内訳: form-template-mapping.md §2 の67件 ＋ Q-45（2026-08-18浅賀MTG・2026-08-19 CEO決定）で
# 追加した Instagram ID/パスワードの2件（必須入力）＝ 計69件・8ステップ。
RSpec.describe BridgePlusFormTemplateSeeder do
  it "Product/FormTemplate/FormStep/FormField/OptionGroupを冪等に作成する" do
    expect { described_class.call }.to change(FormField, :count).by(69)
      .and change(OptionGroup, :count).by(7)

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

  it "R5-5b: payment_methodフィールドの選択肢はOptionGroupではなくPaymentMethodマスタから生成される" do
    StatusSeeder.call
    described_class.call

    field = FormField.find_by!(field_key: "payment_method")
    expect(field.input_options["choices"]).to eq(
      [ %w[bank_transfer 預金口座振替], %w[credit クレジット], %w[bundled おまとめ] ]
    )
    expect(OptionGroup.exists?(key: "payment_method")).to be false
  end

  it "OptionGroup(prefecture)は47都道府県のOptionValueを持つ" do
    described_class.call

    group = OptionGroup.find_by!(key: "prefecture")
    expect(group.option_values.count).to eq(47)
  end

  # master-data-design-policy.md §5-2/§5-3: 管理画面の選択肢一覧に「業務用でない値」を残さない。
  describe "廃止済みOptionGroupの掃除" do
    it "開発用ダミー（group_key_<数字>）はOptionValueごと削除される" do
      dummy = OptionGroup.create!(key: "group_key_1", label: "選択肢グループ1")
      dummy.option_values.create!(value: "a", label: "a")
      other = OptionGroup.create!(key: "group_key_99", label: "選択肢グループ99")

      described_class.call

      expect(OptionGroup.exists?(dummy.id)).to be false
      expect(OptionGroup.exists?(other.id)).to be false
      expect(OptionValue.where(option_group_id: dummy.id)).to be_empty
    end

    it "似た名前でも実データ（group_key_main等）は削除しない" do
      keeper = OptionGroup.create!(key: "group_key_main", label: "実データ")

      described_class.call

      expect(OptionGroup.exists?(keeper.id)).to be true
    end

    it "R5-5b昇格後は旧OptionGroup(payment_method)を削除する" do
      StatusSeeder.call # PaymentMethodマスタを投入＝昇格済みの状態
      OptionGroup.create!(key: "payment_method", label: "お支払方法")

      described_class.call

      expect(OptionGroup.exists?(key: "payment_method")).to be false
    end

    it "R5-5b昇格前にシードされた古いpayment_method選択肢は再実行でマスタの値へ同期される" do
      StatusSeeder.call
      described_class.call
      field = FormField.find_by!(field_key: "payment_method")
      # 昇格前の状態（旧OptionGroup由来のラベル値）を再現する
      field.update!(input_options: { "choices" => [ %w[預金口座振替 預金口座振替], %w[クレジット クレジット] ] })

      described_class.call

      expect(field.reload.input_options["choices"]).to eq(
        [ %w[bank_transfer 預金口座振替], %w[credit クレジット], %w[bundled おまとめ] ]
      )
    end

    it "PaymentMethodマスタが未投入（昇格前）のときは旧OptionGroup(payment_method)を残す" do
      PaymentMethod.delete_all
      legacy = OptionGroup.create!(key: "payment_method", label: "お支払方法")

      described_class.call

      expect(OptionGroup.exists?(legacy.id)).to be true
    end
  end
end
