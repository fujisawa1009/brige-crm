# フォームビルダー（04 R3タスク6）。FormTemplate 1─* FormStep 1─* FormField を1画面のネスト属性
# フォームでまとめて編集する（動的フィールド追加・並び替え程度で十分という指示を踏まえ、
# FormStep/FormField単体の専用CRUD画面は作らない）。
class Admin::FormTemplatesController < Admin::BaseController
  before_action :set_form_template, only: %i[show edit update destroy]

  def index
    @form_templates = policy_scope(FormTemplate).order(:name)
  end

  def show
    authorize @form_template
  end

  def new
    @form_template = FormTemplate.new
    @form_template.form_steps.build.form_fields.build
    authorize @form_template
  end

  def edit
    authorize @form_template
  end

  def create
    @form_template = FormTemplate.new(form_template_params)
    authorize @form_template

    if @form_template.save
      redirect_to admin_form_template_path(@form_template), notice: "フォームテンプレートを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @form_template

    if @form_template.update(form_template_params)
      redirect_to admin_form_template_path(@form_template), notice: "フォームテンプレートを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @form_template

    if @form_template.destroy
      redirect_to admin_form_templates_path, notice: "フォームテンプレートを削除しました。"
    else
      redirect_to admin_form_template_path(@form_template), alert: @form_template.errors.full_messages.to_sentence
    end
  end

  private

  def set_form_template
    @form_template = FormTemplate.find(params[:id])
  end

  def form_template_params
    params.require(:form_template).permit(
      :product_id, :name, :is_active,
      form_steps_attributes: [
        :id, :step_number, :name, :_destroy,
        form_fields_attributes: [
          :id, :field_key, :label, :field_type, :target_table, :target_column,
          :required, :sort_order, :lock_after_status, :input_options_json, :validation_rules_json, :_destroy,
          editable_by_tier: []
        ]
      ]
    )
  end
end
