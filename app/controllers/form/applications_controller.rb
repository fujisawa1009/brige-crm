# 動的マルチステップ申込（04 R3タスク4・5）。営業担当者ログイン後、商材を選び
# （#new/#create）→ FormStep/FormField定義に基づくステップを1つずつ進み（#show_step/#update_step）
# → 確認・完了（#complete/#submit）する。
#
# ステップの回答はApplication#form_data(jsonb)に随時保存し、最終送信（#submit）で初めて
# Form::ApplicationSubmissionServiceがCustomer/Store/Orderを1トランザクションで生成する
# （申込完了トランザクションのrequest specでロールバックを検証しやすくするため、モデル生成は
# ここに一本化し、途中ステップでは一切実体を作らない）。
class Form::ApplicationsController < Form::BaseController
  before_action :set_application, only: %i[show_step update_step complete submit]
  before_action :set_form_step, only: %i[show_step update_step]

  helper_method :product_option_field?, :product_option_choices

  def new
    @products = Product.sellable_by(current_sales_representative.agency).active
                        .select { |product| product.form_template&.is_active? }
  end

  def create
    product = Product.sellable_by(current_sales_representative.agency).active.find_by(id: params[:product_id])

    if product.nil? || product.form_template.blank? || !product.form_template.is_active?
      redirect_to form_new_application_path, alert: "選択された商材は現在お申込みいただけません。"
      return
    end

    application = Application.create!(
      sales_representative: current_sales_representative,
      agency: current_sales_representative.agency,
      product: product
    )
    redirect_to form_application_step_path(token: application.token, step_number: 1)
  end

  def show_step
    return redirect_to_complete! if @application.completed?

    @fields = editable_fields
  end

  def update_step
    return redirect_to_complete! if @application.completed?

    @fields = editable_fields
    result  = Form::DynamicFormValidator.new(@form_step, step_params, product: @application.product).call

    if result.valid?
      persist_step_answers!
      redirect_to next_step_path
    else
      @errors = result.errors
      render :show_step, status: :unprocessable_entity
    end
  end

  def complete
  end

  def submit
    return redirect_to_complete! if @application.completed?

    result = Form::ApplicationSubmissionService.new(@application).call

    if result.success?
      notify_completion!(result.order)
      redirect_to form_application_complete_path(token: @application.token), notice: "申込を受け付けました。"
    else
      @submission_errors = result.errors
      render :complete, status: :unprocessable_entity
    end
  end

  # target_table: "order" / target_column: "product_option_ids" は、選択肢を固定入力せず
  # 「この商材に紐づくProductOption」から動的に導出する特別枠（app/models/form_field.rb冒頭コメント
  # 参照）。ビュー（_field_input.html.erb）から使うため helper_method 化している。
  def product_option_field?(field)
    field.target_table == "order" && field.target_column == "product_option_ids"
  end

  def product_option_choices
    @application.product.product_options.active.ordered.map { |option| [ option.id.to_s, option.name ] }
  end

  private

  # current_sales_representative配下に絞る（他営業担当者のtokenでは404にする。IDOR対策）。
  def set_application
    @application = current_sales_representative.applications.find_by!(token: params[:token])
  end

  def set_form_step
    @form_step = @application.form_template.form_steps.find_by!(step_number: step_number)
  end

  def step_number
    params[:step_number].to_i
  end

  def editable_fields
    @form_step.form_fields.editable_by(FormField::TIER_SALES_REPRESENTATIVE).ordered
  end

  # 個別キー読み出しのみに使うため permit しない（Model.newへ渡すマスアサインには使わない。
  # persist_step_answers!はeditable_fieldsのfield_keyだけを拾うため、未知キーが混ざっても無害）。
  def step_params
    params.fetch(:answers, {})
  end

  def persist_step_answers!
    updates = editable_fields.each_with_object({}) do |field, memo|
      next unless step_params.key?(field.field_key)

      memo[field.field_key] = step_params[field.field_key]
    end

    @application.form_data = @application.form_data.merge(updates)
    @application.current_step_number = [ @application.current_step_number, step_number + 1 ].max
    @application.save!
  end

  def next_step_path
    next_step = @application.form_template.form_steps.find_by(step_number: step_number + 1)

    if next_step
      form_application_step_path(token: @application.token, step_number: next_step.step_number)
    else
      form_application_complete_path(token: @application.token)
    end
  end

  def redirect_to_complete!
    redirect_to form_application_complete_path(token: @application.token)
  end

  def notify_completion!(order)
    Form::ApplicationMailer.confirmation(@application).deliver_later
    StaffNotificationMailer.new_application(order).deliver_later

    # R4のSystemNotification基盤が無いため「まずは監査ログ記録＋メール通知だけ」の最小実装
    # （04 R3タスク5）。Current.userはform文脈では常にnil（TracksUserはUserのみ想定）のため、
    # Auditableの自動フックには乗らず、ここで明示的にAuditLogを作る。
    AuditLog.create!(
      user_id:        current_sales_representative.id,
      user_type:      "SalesRepresentative",
      action:         "application_completed",
      resource_type:  "Application",
      resource_id:    @application.id,
      resource_label: @application.token,
      metadata:       { order_id: order.id, customer_id: order.customer_id },
      ip_address:     request.remote_ip,
      source:         "web",
      request_id:     request.request_id
    )
  end
end
