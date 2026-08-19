# 案件ステータスマスタ管理（04 R2タスク4）。
class Admin::OrderStatusesController < Admin::BaseController
  before_action :set_order_status, only: %i[show edit update destroy]

  def index
    @pagy, @order_statuses = pagy(policy_scope(OrderStatus).order(:sort_order))
  end

  def show
    authorize @order_status
  end

  def new
    @order_status = OrderStatus.new
    authorize @order_status
  end

  def edit
    authorize @order_status
  end

  def create
    @order_status = OrderStatus.new(order_status_params)
    authorize @order_status

    if @order_status.save
      redirect_to admin_order_status_path(@order_status), notice: "ステータスを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @order_status

    if @order_status.update(order_status_params)
      redirect_to admin_order_status_path(@order_status), notice: "ステータスを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @order_status

    if @order_status.destroy
      redirect_to admin_order_statuses_path, notice: "ステータスを削除しました。"
    else
      redirect_to admin_order_status_path(@order_status), alert: @order_status.errors.full_messages.to_sentence
    end
  end

  private

  def set_order_status
    @order_status = OrderStatus.find(params[:id])
  end

  def order_status_params
    # is_completed（R6-6）: 案件一覧の「完了済みを含む」検索が既定除外する終端ステータスかどうかの
    # フラグ。ステータス追加・見直し時に運用側で切り替えられるよう編集画面から更新可能にする。
    params.require(:order_status).permit(:code, :label, :sort_order, :is_active, :is_completed)
  end
end
