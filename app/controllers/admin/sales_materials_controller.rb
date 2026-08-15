# 営業資料マスタ管理（04 R2タスク6）。実ファイルアップロードUIはR2スコープ外（file_pathを
# 文字列として直接入力する運用。ActiveStorage導入はファイル配布要件が具体化してから判断する）。
class Admin::SalesMaterialsController < Admin::BaseController
  before_action :set_sales_material, only: %i[show edit update destroy]

  def index
    @pagy, @sales_materials = pagy(policy_scope(SalesMaterial).order(:sort_order))
  end

  def show
    authorize @sales_material
  end

  def new
    @sales_material = SalesMaterial.new
    authorize @sales_material
  end

  def edit
    authorize @sales_material
  end

  def create
    @sales_material = SalesMaterial.new(sales_material_params)
    authorize @sales_material

    if @sales_material.save
      redirect_to admin_sales_material_path(@sales_material), notice: "営業資料を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @sales_material

    if @sales_material.update(sales_material_params)
      redirect_to admin_sales_material_path(@sales_material), notice: "営業資料を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @sales_material

    if @sales_material.destroy
      redirect_to admin_sales_materials_path, notice: "営業資料を削除しました。"
    else
      redirect_to admin_sales_material_path(@sales_material),
                  alert: @sales_material.errors.full_messages.to_sentence
    end
  end

  private

  def set_sales_material
    @sales_material = SalesMaterial.find(params[:id])
  end

  def sales_material_params
    params.require(:sales_material).permit(
      :title, :category, :description, :file_path, :original_file_name, :file_size, :mime_type,
      :is_published, :sort_order
    )
  end
end
