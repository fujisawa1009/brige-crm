# フォームビルダー（Admin::FormTemplates）のUI日本語化（実装後の非エンジニア向け刷新）で使う
# ラベルカタログ。config/form_field_column_labels.yml を読み込み、target_table（顧客/店舗/案件/
# 案件詳細）とその許可カラムの日本語ラベルを提供する。
#
# FormField側の許可カラム判定ロジック（FormField.allowed_target_columns_for）は一切変更せず、
# こちらは「許可された値に日本語ラベルを添える」表示専用の層として分離する（バックエンドの
# バリデーション・ホワイトリストと、表示ラベルの管理を別関心事として保つ）。
#
# Form::ApplicationSubmissionService / Form::DynamicFormValidator と同じ Form:: 名前空間に置く
# （FormFieldは既にActiveRecordモデルのクラス名のため、モジュールとして再オープンできない）。
module Form
  class ColumnLabelCatalog
    CONFIG_PATH = Rails.root.join("config/form_field_column_labels.yml")

    class << self
      # target_table（例: "customer"）の日本語テーブル名（例: "顧客"）。未登録なら値をそのまま返す。
      def table_label(target_table)
        tables.fetch(target_table.to_s, target_table.to_s)
      end

      # target_table select（FormField::TARGET_TABLES）の選択肢。表示テキストのみ日本語化し、
      # 送信される値（target_table）自体はTARGET_TABLESのまま変更しない。
      def table_options
        FormField::TARGET_TABLES.map { |table| [ table_label(table), table ] }
      end

      # target_table・カラム名 => 日本語ラベル。カタログに無ければカラム名をそのまま返す
      # （config/form_field_column_labels.yml の網羅性は spec/models/form/column_label_catalog_spec.rb
      # が別途検証するため、ここはフェイルセーフとしてカラム名フォールバックのみ行う）。
      def column_label(target_table, column)
        columns.dig(target_table.to_s, column.to_s) || column.to_s
      end

      # target_column selectの選択肢（値=カラム名、表示=日本語ラベル）。許可カラムの正は
      # FormField.allowed_target_columns_for に一本化し、ここでは日本語ラベルを添えるだけに留める。
      def target_column_options(target_table)
        FormField.allowed_target_columns_for(target_table).sort.map { |column| [ column_label(target_table, column), column ] }
      end

      # target_table => target_column_options のハッシュ（4テーブル分）。ビューでJSON化して
      # data属性へ埋め込み、Stimulus（target-column-filter コントローラ）が target_table の選択に
      # 応じてtarget_columnの選択肢をサーバ往復なしで絞り込むために使う。
      def target_column_options_by_table
        FormField::TARGET_TABLES.index_with { |table| target_column_options(table) }
      end

      private

      def tables
        @tables ||= config.fetch("tables")
      end

      def columns
        @columns ||= config.fetch("columns")
      end

      def config
        @config ||= YAML.load_file(CONFIG_PATH)
      end
    end
  end
end
