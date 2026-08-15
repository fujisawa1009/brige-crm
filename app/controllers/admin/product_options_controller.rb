# 商材オプションマスタ管理（04 R2タスク3）。
class Admin::ProductOptionsController < Admin::BaseController
  before_action :set_product_option, only: %i[show edit update destroy]

  def index
    @pagy, @product_options = pagy(policy_scope(ProductOption).order(:product_id, :sort_order))
  end

  def show
    authorize @product_option
  end

  def new
    @product_option = ProductOption.new
    authorize @product_option
  end

  def edit
    authorize @product_option
  end

  def create
    @product_option = ProductOption.new(product_option_params)
    authorize @product_option

    if @product_option.save
      redirect_to admin_product_option_path(@product_option), notice: "オプションを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @product_option

    if @product_option.update(product_option_params)
      redirect_to admin_product_option_path(@product_option), notice: "オプションを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product_option

    if @product_option.destroy
      redirect_to admin_product_options_path, notice: "オプションを削除しました。"
    else
      redirect_to admin_product_option_path(@product_option),
                  alert: @product_option.errors.full_messages.to_sentence
    end
  end

  private

  def set_product_option
    @product_option = ProductOption.find(params[:id])
  end

  def product_option_params
    params.require(:product_option).permit(:product_id, :name, :description, :monthly_fee, :sort_order, :is_active)
  end
end
