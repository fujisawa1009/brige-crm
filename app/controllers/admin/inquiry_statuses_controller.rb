# 問い合わせステータスマスタ管理（04 R4タスク2・決定D-11）。CustomerStatusesController同型。
# is_system=trueの行はcode変更・削除不可（InquiryStatus#code_cannot_change_for_system_record）。
class Admin::InquiryStatusesController < Admin::BaseController
  before_action :set_inquiry_status, only: %i[show edit update destroy]

  def index
    scope = policy_scope(InquiryStatus).order(:category, :sort_order)
    scope = scope.for_category(params[:category]) if params[:category].present?
    @pagy, @inquiry_statuses = pagy(scope)
  end

  def show
    authorize @inquiry_status
  end

  def new
    @inquiry_status = InquiryStatus.new
    authorize @inquiry_status
  end

  def edit
    authorize @inquiry_status
  end

  def create
    @inquiry_status = InquiryStatus.new(inquiry_status_params)
    authorize @inquiry_status

    if @inquiry_status.save
      redirect_to admin_inquiry_status_path(@inquiry_status), notice: "ステータスを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @inquiry_status

    if @inquiry_status.update(inquiry_status_params)
      redirect_to admin_inquiry_status_path(@inquiry_status), notice: "ステータスを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @inquiry_status

    if @inquiry_status.destroy
      redirect_to admin_inquiry_statuses_path, notice: "ステータスを削除しました。"
    else
      redirect_to admin_inquiry_status_path(@inquiry_status), alert: @inquiry_status.errors.full_messages.to_sentence
    end
  end

  private

  def set_inquiry_status
    @inquiry_status = InquiryStatus.find(params[:id])
  end

  def inquiry_status_params
    params.require(:inquiry_status).permit(:category, :code, :label, :sort_order, :is_active)
  end
end
