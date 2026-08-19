# 申込ステータス（旧称: 顧客ステータス）マスタ管理（04 R2タスク4）。is_system=trueの行はcode変更・削除不可
# （SystemManagedStatus concern参照。フォーム上もcodeフィールドをreadonly表示する想定）。
class Admin::CustomerStatusesController < Admin::BaseController
  before_action :set_customer_status, only: %i[show edit update destroy]

  def index
    @pagy, @customer_statuses = pagy(policy_scope(CustomerStatus).order(:sort_order))
  end

  def show
    authorize @customer_status
  end

  def new
    @customer_status = CustomerStatus.new
    authorize @customer_status
  end

  def edit
    authorize @customer_status
  end

  def create
    @customer_status = CustomerStatus.new(customer_status_params)
    authorize @customer_status

    if @customer_status.save
      redirect_to admin_customer_status_path(@customer_status), notice: "ステータスを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @customer_status

    if @customer_status.update(customer_status_params)
      redirect_to admin_customer_status_path(@customer_status), notice: "ステータスを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer_status

    if @customer_status.destroy
      redirect_to admin_customer_statuses_path, notice: "ステータスを削除しました。"
    else
      redirect_to admin_customer_status_path(@customer_status),
                  alert: @customer_status.errors.full_messages.to_sentence
    end
  end

  private

  def set_customer_status
    @customer_status = CustomerStatus.find(params[:id])
  end

  def customer_status_params
    params.require(:customer_status).permit(:code, :label, :sort_order, :is_active)
  end
end
