# 商材マスタ管理（04 R2タスク3）。代理店スコープ対象外＝全代理店共通閲覧（MasterDataPolicy参照）。
class Admin::ProductsController < Admin::BaseController
  before_action :set_product, only: %i[show edit update destroy]

  def index
    @pagy, @products = pagy(policy_scope(Product).order(:name))
  end

  def show
    authorize @product
  end

  def new
    @product = Product.new
    authorize @product
  end

  def edit
    authorize @product
  end

  def create
    @product = Product.new(product_params)
    authorize @product

    if @product.save
      redirect_to admin_product_path(@product), notice: "商材を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @product

    if @product.update(product_params)
      redirect_to admin_product_path(@product), notice: "商材を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product

    if @product.destroy
      redirect_to admin_products_path, notice: "商材を削除しました。"
    else
      redirect_to admin_product_path(@product), alert: @product.errors.full_messages.to_sentence
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :code, :description, :is_active)
  end
end
