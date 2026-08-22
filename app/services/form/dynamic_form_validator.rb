# FormStep/FormField定義に基づく動的バリデーション（04 R3タスク4）。
#
# クライアント側（Stimulus・app/javascript/controllers/dynamic_form_controller.js）はrequired属性等で
# 即時フィードバックを返すが、送信の可否は必ずここ（サーバ側）で再判定する（二重バリデーション）。
# フィールド定義そのものが動的（管理画面のフォームビルダーで随時変わる）ため、固定のActiveModel
# バリデータではなくfield_type/required/validation_rules/target_tableを読んで都度組み立てる。
module Form
  class DynamicFormValidator
    Result = Struct.new(:valid?, :errors, keyword_init: true)

    def initialize(form_step, params, product:)
      @form_step = form_step
      @params    = params
      @product   = product
    end

    def call
      errors = {}

      @form_step.form_fields.editable_by(FormField::TIER_SALES_REPRESENTATIVE).ordered.each do |field|
        field_errors = validate_field(field)
        errors[field.field_key] = field_errors if field_errors.any?
      end

      Result.new(valid?: errors.empty?, errors: errors)
    end

    private

    def validate_field(field)
      value = @params[field.field_key]
      errs  = []

      if blank_for?(field, value)
        errs << "は必須項目です" if field.required?
        return errs # 未入力の任意項目に型・桁数チェックをかける意味は無い
      end

      errs.concat(type_errors(field, value))
      errs.concat(length_errors(field, value))
      errs.concat(association_errors(field, value))

      errs
    end

    def blank_for?(field, value)
      field.field_type == "checkbox_group" ? Array(value).reject(&:blank?).empty? : value.blank?
    end

    def type_errors(field, value)
      case field.field_type
      when "integer"
        Integer(value)
        []
      when "date"
        Date.parse(value)
        []
      when "select"
        choices = Array(field.input_options["choices"]).map { |pair| pair[0].to_s }
        choices.include?(value.to_s) ? [] : [ "は選択肢の中から選んでください" ]
      else
        []
      end
    rescue ArgumentError, TypeError
      [ "の形式が正しくありません" ]
    end

    def length_errors(field, value)
      max_length = field.validation_rules["max_length"]
      return [] if max_length.blank?

      # checkbox_groupは保存時に「・」連結の1文字列になる（Form::ApplicationSubmissionService#cast_value）
      # ため、桁数チェックも連結後の文字列に対して行う（attribute_1〜11等のstring(100)列あふれ対策）。
      value = Array(value).reject(&:blank?).join("・") if field.field_type == "checkbox_group"
      return [] if !value.respond_to?(:length) || value.length <= max_length.to_i

      [ "は#{max_length}文字以内で入力してください" ]
    end

    # target_table: "order" / target_column: "product_option_ids" のような集合idsライター宛てフィールドは、
    # 選ばれたIDが本当にこの商材のProductOptionかを検証する（他商材のオプションIDを紛れ込ませて
    # Orderに紐づけられてしまう権限昇格・データ不整合経路を塞ぐ）。
    def association_errors(field, value)
      return product_option_errors(value) if order_column?(field, "product_option_ids")
      return product_initial_fee_errors(value) if order_column?(field, "product_initial_fee_id")

      []
    end

    def order_column?(field, column)
      field.target_table == "order" && field.target_column == column
    end

    def product_option_errors(value)
      ids = Array(value).reject(&:blank?)
      return [] if ids.empty?

      valid_count = @product.product_options.active.where(id: ids).count
      valid_count == ids.size ? [] : [ "に商材の対象外のオプションが含まれています" ]
    end

    # 初期費用（P2）はselect選択肢の照合に加えて、値が本当にこの商材のProductInitialFeeかを検証する
    # （選択肢はシーダー投入時点のマスタ複製のため、他商材のIDを直接POSTされる経路をここで塞ぐ）。
    def product_initial_fee_errors(value)
      return [] if value.blank?

      @product.product_initial_fees.active.exists?(id: value) ? [] : [ "に商材の対象外の初期費用が指定されています" ]
    end
  end
end
