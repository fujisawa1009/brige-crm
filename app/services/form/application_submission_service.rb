# 申込完了トランザクション（04 R3タスク5）。Applicationがステップをまたいで蓄積したform_dataを、
# FormField定義（target_table/target_column）に従ってCustomer + Store + Order（+選択オプション）へ
# 1トランザクションで一括反映する。Laravel側の教訓（01§7 T-1: 決済状態機械・申込トランザクションの
# テスト不在）を踏まえ、途中のどのモデルが不正でも save! で例外を上げてロールバックを
# 呼び出し元が確認できるようにする（アプリケーション側で個別にrescueして握りつぶさない）。
module Form
  class ApplicationSubmissionService
    Result = Struct.new(:success?, :customer, :store, :order, :errors, keyword_init: true)

    # target_table => 「Applicationからどうレコードを得るか／保存後どうApplicationへ紐付けるか」
    TARGET_BUILDERS = %w[customer store order order_work_detail].freeze

    def initialize(application)
      @application = application
      @product     = application.product
      @agency      = application.sales_representative.agency
    end

    def call
      return already_completed_result if @application.completed?

      customer = store = order = nil

      ActiveRecord::Base.transaction do
        contract_condition = current_contract_condition!

        customer = Customer.new(agency: @agency, sales_representative: @application.sales_representative)
        apply_attributes!(customer, "customer")
        customer.save!

        store = Store.new(customer: customer)
        apply_attributes!(store, "store")
        store.save!

        order = Order.new(
          agency: @agency,
          customer: customer,
          store: store,
          sales_representative: @application.sales_representative,
          contract_condition: contract_condition
        )
        apply_attributes!(order, "order")
        assign_auto_values!(order)
        order.save!

        apply_order_work_detail!(order)

        # R3レビュー指摘: form_data(jsonb・暗号化なし)にはSNS認証情報等の機密情報が入りうる。
        # 各カラムへ転記済みの完了時点で平文のまま残す理由が無いため、同一トランザクションでクリアする。
        @application.update!(
          status: "completed", customer: customer, store: store, order: order, completed_at: Time.current,
          form_data: {}
        )
      end

      Result.new(success?: true, customer: customer, store: store, order: order, errors: {})
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, customer: nil, store: nil, order: nil, errors: { base: [ e.message ] })
    end

    private

    def already_completed_result
      Result.new(success?: true, customer: @application.customer, store: @application.store,
                 order: @application.order, errors: {})
    end

    # 代理店の現行契約条件（T-3是正どおりOrder#contract_condition_idは必須）。未設定は運用不備であり、
    # フォーム入力の巧拙とは無関係に申込全体を止めるべきエラーのため、Order単体のバリデーションエラー
    # ではなくここで明示的にRecordInvalidを送出する（Customer/Storeが作られる前に食い止める）。
    def current_contract_condition!
      condition = @agency.current_contract_condition
      return condition if condition

      undecided_order = Order.new
      undecided_order.errors.add(:contract_condition, "が設定されていません（代理店の契約条件が未設定です）")
      raise ActiveRecord::RecordInvalid, undecided_order
    end

    # AILINKフォーム P2「受注日（申込日）＝自動入力」「プラン＝自動入力」対応。
    # - 受注日: フォームに入力欄が無い商材では申込完了日を受注日として記録する（入力欄がある商材は
    #   フォーム値を優先＝||=）。
    # - プラン: 有効プランが1本しかない商材（AILINK等の1価格固定商材）のみ自動確定する。複数プランの
    #   商材（BRIDGE_PLUS等）は従来どおり未設定のまま（プラン選択は管理画面側の業務）。
    def assign_auto_values!(order)
      order.ordered_at ||= Date.current

      active_plans = @product.plans.active
      order.plan ||= active_plans.first if active_plans.one?
    end

    def apply_attributes!(record, target_table)
      fields_for(target_table).each do |field|
        next unless @application.form_data.key?(field.field_key)

        record.public_send("#{field.target_column}=", cast_value(field, @application.form_data[field.field_key]))
      end
    end

    # order_work_detailを対象とするフィールドが1つも定義されていない商材ではOrderWorkDetail自体
    # 作らない（空レコードを量産しない）。
    def apply_order_work_detail!(order)
      fields = fields_for("order_work_detail")
      return if fields.empty?

      detail = order.build_order_work_detail
      fields.each do |field|
        next unless @application.form_data.key?(field.field_key)

        detail.public_send("#{field.target_column}=", cast_value(field, @application.form_data[field.field_key]))
      end
      detail.save!
    end

    def fields_for(target_table)
      all_fields.select { |field| field.target_table == target_table }
    end

    def all_fields
      @all_fields ||= @application.form_template.form_steps.flat_map(&:form_fields)
    end

    def cast_value(field, value)
      case field.field_type
      when "integer"  then value.presence && Integer(value)
      when "date"     then value.presence && Date.parse(value)
      when "boolean"  then ActiveModel::Type::Boolean.new.cast(value)
      when "checkbox_group" then cast_checkbox_group(field, value)
      else value
      end
    end

    # checkbox_groupの保存形: 集合idsライター（product_option_ids等の *_ids）へは配列のまま、
    # 通常のstring/text列（order_work_details.attribute_1〜11・contact_easy_time等）へは
    # 「・」連結の1文字列として保存する（配列をstring列へ代入するとto_s表現がそのまま入るため）。
    # 桁あふれはFormFieldのvalidation_rules.max_lengthとDynamicFormValidatorの連結後チェックで防ぐ。
    def cast_checkbox_group(field, value)
      selected = Array(value).reject(&:blank?)
      field.target_column.to_s.end_with?("_ids") ? selected : selected.join("・")
    end
  end
end
