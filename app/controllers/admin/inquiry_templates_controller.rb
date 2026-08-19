# 問い合わせ返信テンプレート管理（R6-4）。NotificationTemplatesControllerと同型のCRUD。
class Admin::InquiryTemplatesController < Admin::BaseController
  before_action :set_inquiry_template, only: %i[show edit update destroy]

  def index
    scope = policy_scope(InquiryTemplate).order(:category, :name)
    scope = scope.where(category: params[:category]) if params[:category].present?
    @pagy, @inquiry_templates = pagy(scope)
  end

  def show
    authorize @inquiry_template
  end

  def new
    @inquiry_template = InquiryTemplate.new
    authorize @inquiry_template
  end

  def edit
    authorize @inquiry_template
  end

  def create
    @inquiry_template = InquiryTemplate.new(inquiry_template_params)
    authorize @inquiry_template

    if @inquiry_template.save
      redirect_to admin_inquiry_template_path(@inquiry_template), notice: "テンプレートを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @inquiry_template

    if @inquiry_template.update(inquiry_template_params)
      redirect_to admin_inquiry_template_path(@inquiry_template), notice: "テンプレートを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @inquiry_template

    if @inquiry_template.destroy
      redirect_to admin_inquiry_templates_path, notice: "テンプレートを削除しました。"
    else
      redirect_to admin_inquiry_template_path(@inquiry_template),
                  alert: @inquiry_template.errors.full_messages.to_sentence
    end
  end

  private

  def set_inquiry_template
    @inquiry_template = InquiryTemplate.find(params[:id])
  end

  def inquiry_template_params
    params.require(:inquiry_template).permit(:category, :name, :body)
  end
end
