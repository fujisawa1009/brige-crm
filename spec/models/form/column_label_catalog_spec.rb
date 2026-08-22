require "rails_helper"

# フォームビルダー（Admin::FormTemplates）の日本語ラベルカタログ（config/form_field_column_labels.yml
# + Form::ColumnLabelCatalog）。FormField.allowed_target_columns_for が返す全カラム（4テーブル分）に
# ラベルが存在することを検証する。将来カラムがEXTRA_ALLOWED_COLUMNS等で追加されたのに
# config/form_field_column_labels.yml の更新を忘れた場合、ここが落ちて検知する。
RSpec.describe Form::ColumnLabelCatalog do
  describe "config/form_field_column_labels.yml の網羅性" do
    FormField::TARGET_TABLES.each do |target_table|
      it "#{target_table} の許可カラムすべてにラベルが定義されている" do
        allowed_columns = FormField.allowed_target_columns_for(target_table)
        expect(allowed_columns).not_to be_empty

        missing = allowed_columns.reject do |column|
          label = described_class.column_label(target_table, column)
          label.present? && label != column
        end

        expect(missing).to be_empty,
          "#{target_table} の以下のカラムにラベルが未定義です（config/form_field_column_labels.yml へ追加してください）: #{missing.join(', ')}"
      end
    end
  end

  describe ".table_label" do
    it "テーブルキーごとの日本語名を返す" do
      expect(described_class.table_label("customer")).to eq("顧客")
      expect(described_class.table_label("store")).to eq("店舗")
      expect(described_class.table_label("order")).to eq("案件")
      expect(described_class.table_label("order_work_detail")).to eq("案件詳細")
    end

    it "未登録のキーはそのまま返す" do
      expect(described_class.table_label("unknown")).to eq("unknown")
    end
  end

  describe ".table_options" do
    it "FormField::TARGET_TABLESと同じ値集合・順序で[ラベル, 値]の組を返す" do
      expect(described_class.table_options.map(&:last)).to eq(FormField::TARGET_TABLES)
      expect(described_class.table_options.map(&:first)).to eq(%w[顧客 店舗 案件 案件詳細])
    end
  end

  describe ".target_column_options" do
    it "FormField.allowed_target_columns_forと同じカラム集合を持つ" do
      options = described_class.target_column_options("customer")
      expect(options.map(&:last)).to match_array(FormField.allowed_target_columns_for("customer"))
    end

    it "EXTRA_ALLOWED_COLUMNS（決定者確定仕様の固定文言）を含む" do
      options = described_class.target_column_options("order").to_h { |label, value| [ value, label ] }
      expect(options["product_option_ids"]).to eq("オプション（複数選択）")
      expect(options["product_initial_fee_id"]).to eq("初期費用プラン")
    end
  end

  describe ".target_column_options_by_table" do
    it "4テーブル分すべてのキーを持つ" do
      expect(described_class.target_column_options_by_table.keys).to match_array(FormField::TARGET_TABLES)
    end
  end
end
