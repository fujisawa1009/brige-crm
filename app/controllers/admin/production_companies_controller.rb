# 制作会社マスタ管理（04 R2タスク6）。
class Admin::ProductionCompaniesController < Admin::BaseController
  before_action :set_production_company, only: %i[show edit update destroy]

  def index
    @pagy, @production_companies = pagy(policy_scope(ProductionCompany).order(:name))
  end

  def show
    authorize @production_company
  end

  def new
    @production_company = ProductionCompany.new
    authorize @production_company
  end

  def edit
    authorize @production_company
  end

  def create
    @production_company = ProductionCompany.new(production_company_params)
    authorize @production_company

    if @production_company.save
      redirect_to admin_production_company_path(@production_company), notice: "制作会社を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @production_company

    if @production_company.update(production_company_params)
      redirect_to admin_production_company_path(@production_company), notice: "制作会社を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @production_company

    if @production_company.destroy
      redirect_to admin_production_companies_path, notice: "制作会社を削除しました。"
    else
      redirect_to admin_production_company_path(@production_company),
                  alert: @production_company.errors.full_messages.to_sentence
    end
  end

  private

  def set_production_company
    @production_company = ProductionCompany.find(params[:id])
  end

  def production_company_params
    params.require(:production_company).permit(:name, :contact_name, :email, :phone, :notes, :is_active)
  end
end
