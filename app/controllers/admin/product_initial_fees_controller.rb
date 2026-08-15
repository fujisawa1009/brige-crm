# 初期費用テンプレートマスタ管理（04 R2タスク3）。
class Admin::ProductInitialFeesController < Admin::BaseController
  before_action :set_product_initial_fee, only: %i[show edit update destroy]

  def index
    @pagy, @product_initial_fees = pagy(policy_scope(ProductInitialFee).order(:product_id, :sort_order))
  end

  def show
    authorize @product_initial_fee
  end

  def new
    @product_initial_fee = ProductInitialFee.new
    authorize @product_initial_fee
  end

  def edit
    authorize @product_initial_fee
  end

  def create
    @product_initial_fee = ProductInitialFee.new(product_initial_fee_params)
    authorize @product_initial_fee

    if @product_initial_fee.save
      redirect_to admin_product_initial_fee_path(@product_initial_fee), notice: "初期費用を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @product_initial_fee

    if @product_initial_fee.update(product_initial_fee_params)
      redirect_to admin_product_initial_fee_path(@product_initial_fee), notice: "初期費用を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product_initial_fee

    if @product_initial_fee.destroy
      redirect_to admin_product_initial_fees_path, notice: "初期費用を削除しました。"
    else
      redirect_to admin_product_initial_fee_path(@product_initial_fee),
                  alert: @product_initial_fee.errors.full_messages.to_sentence
    end
  end

  private

  def set_product_initial_fee
    @product_initial_fee = ProductInitialFee.find(params[:id])
  end

  def product_initial_fee_params
    params.require(:product_initial_fee).permit(:product_id, :name, :amount, :sort_order, :is_active)
  end
end
