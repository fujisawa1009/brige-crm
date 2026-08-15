# プランマスタ管理（04 R2タスク3）。
class Admin::PlansController < Admin::BaseController
  before_action :set_plan, only: %i[show edit update destroy]

  def index
    @pagy, @plans = pagy(policy_scope(Plan).order(:product_id, :sort_order))
  end

  def show
    authorize @plan
  end

  def new
    @plan = Plan.new
    authorize @plan
  end

  def edit
    authorize @plan
  end

  def create
    @plan = Plan.new(plan_params)
    authorize @plan

    if @plan.save
      redirect_to admin_plan_path(@plan), notice: "プランを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @plan

    if @plan.update(plan_params)
      redirect_to admin_plan_path(@plan), notice: "プランを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @plan

    if @plan.destroy
      redirect_to admin_plans_path, notice: "プランを削除しました。"
    else
      redirect_to admin_plan_path(@plan), alert: @plan.errors.full_messages.to_sentence
    end
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(:product_id, :name, :code, :monthly_fee, :sort_order, :is_active)
  end
end
