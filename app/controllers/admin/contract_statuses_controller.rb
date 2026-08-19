# 契約ステータスマスタ管理（04 R5-1）。order_statuses_controllerと同型。
class Admin::ContractStatusesController < Admin::BaseController
  before_action :set_contract_status, only: %i[show edit update destroy]

  def index
    @pagy, @contract_statuses = pagy(policy_scope(ContractStatus).order(:sort_order))
  end

  def show
    authorize @contract_status
  end

  def new
    @contract_status = ContractStatus.new
    authorize @contract_status
  end

  def edit
    authorize @contract_status
  end

  def create
    @contract_status = ContractStatus.new(contract_status_params)
    authorize @contract_status

    if @contract_status.save
      redirect_to admin_contract_status_path(@contract_status), notice: "ステータスを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @contract_status

    if @contract_status.update(contract_status_params)
      redirect_to admin_contract_status_path(@contract_status), notice: "ステータスを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @contract_status

    if @contract_status.destroy
      redirect_to admin_contract_statuses_path, notice: "ステータスを削除しました。"
    else
      redirect_to admin_contract_status_path(@contract_status), alert: @contract_status.errors.full_messages.to_sentence
    end
  end

  private

  def set_contract_status
    @contract_status = ContractStatus.find(params[:id])
  end

  def contract_status_params
    params.require(:contract_status).permit(:code, :label, :sort_order, :is_active)
  end
end
