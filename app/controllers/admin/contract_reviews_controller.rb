# 契約ワークフロー状態機械のイベント投入（04 R5-1）。Order#transition_contract_to!への薄い窓口。
# 権限は親OrderのOrderPolicy#transition_contract?（staff_scope?のみ。basic-design.md §9〜§12が
# 一貫して「管理者が」行う工程として記述しているため）。
class Admin::ContractReviewsController < Admin::BaseController
  before_action :set_order

  def create
    authorize @order, :transition_contract?

    @order.transition_contract_to!(
      contract_review_params[:event],
      reason: contract_review_params[:reason].presence,
      comment: contract_review_params[:comment].presence,
      returned_to: contract_review_params[:returned_to].presence,
      performed_by: current_user
    )
    redirect_to admin_order_path(@order), notice: "契約ステータスを更新しました。"
  rescue Order::InvalidContractTransition => e
    redirect_to admin_order_path(@order), alert: e.message
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  end

  def contract_review_params
    params.require(:contract_review).permit(:event, :reason, :comment, :returned_to)
  end
end
