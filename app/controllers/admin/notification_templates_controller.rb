# 通知テンプレート管理（04 R4タスク3）。
class Admin::NotificationTemplatesController < Admin::BaseController
  before_action :set_notification_template, only: %i[show edit update destroy]

  def index
    @pagy, @notification_templates = pagy(policy_scope(NotificationTemplate).order(:name))
  end

  def show
    authorize @notification_template
  end

  def new
    @notification_template = NotificationTemplate.new
    authorize @notification_template
  end

  def edit
    authorize @notification_template
  end

  def create
    @notification_template = NotificationTemplate.new(notification_template_params)
    authorize @notification_template

    if @notification_template.save
      redirect_to admin_notification_template_path(@notification_template), notice: "テンプレートを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @notification_template

    if @notification_template.update(notification_template_params)
      redirect_to admin_notification_template_path(@notification_template), notice: "テンプレートを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @notification_template

    if @notification_template.destroy
      redirect_to admin_notification_templates_path, notice: "テンプレートを削除しました。"
    else
      redirect_to admin_notification_template_path(@notification_template),
                  alert: @notification_template.errors.full_messages.to_sentence
    end
  end

  private

  def set_notification_template
    @notification_template = NotificationTemplate.find(params[:id])
  end

  def notification_template_params
    params.require(:notification_template).permit(:name, :template_type, :subject, :body)
  end
end
