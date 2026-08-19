# 契約条件管理（04 R1・Column.md §6）。契約条件は商取引条件そのものであり、作成・更新・削除は
# 全て staff（admin/実務運用者）のみ（ContractConditionPolicy参照）。代理店/代理店グループユーザーは
# index/show のみ可（自代理店の契約条件を閲覧できるが編集はできない）。
#
# 申し送り（T-3・04 R1本文）: 「受注（Order）側への紐づけ」是正はOrderがR2で作られるまで未実装。
# R1では Agency 1─* ContractCondition の単体CRUDのみ（app/models/contract_condition.rb 参照）。
class Admin::ContractConditionsController < Admin::BaseController
  before_action :set_contract_condition, only: [ :show, :edit, :update, :destroy ]

  def index
    scope = policy_scope(ContractCondition).includes(:agency).order(effective_from: :desc)
    scope = scope.where("contract_conditions.name ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    if params[:agency_q].present?
      scope = scope.joins(:agency).where("agencies.name ILIKE :q OR agencies.agency_code ILIKE :q", q: "%#{params[:agency_q]}%")
    end
    case params[:status]
    when "current" then scope = scope.where(effective_until: nil)
    when "past"    then scope = scope.where.not(effective_until: nil)
    end

    @pagy, @contract_conditions = pagy(scope)
  end

  def show
    authorize @contract_condition
  end

  def new
    @contract_condition = ContractCondition.new
    authorize @contract_condition
  end

  def edit
    authorize @contract_condition
  end

  def create
    @contract_condition = ContractCondition.new(contract_condition_params)
    authorize @contract_condition

    if @contract_condition.save
      redirect_to admin_contract_condition_path(@contract_condition), notice: "契約条件を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @contract_condition

    if @contract_condition.update(contract_condition_params)
      redirect_to admin_contract_condition_path(@contract_condition), notice: "契約条件を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @contract_condition

    if @contract_condition.destroy
      redirect_to admin_contract_conditions_path, notice: "契約条件を削除しました。"
    else
      redirect_to admin_contract_condition_path(@contract_condition),
        alert: @contract_condition.errors.full_messages.to_sentence
    end
  end

  private

  def set_contract_condition
    @contract_condition = ContractCondition.find(params[:id])
  end

  def contract_condition_params
    params.require(:contract_condition).permit(:agency_id, :name, :effective_from, :effective_until)
  end
end
