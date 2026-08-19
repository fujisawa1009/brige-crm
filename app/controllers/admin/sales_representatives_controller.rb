# 営業担当者管理（04 R1・Column.md §7）。作成は staff（admin/実務運用者）のみ
# （SalesRepresentativePolicy参照）。更新・削除は自代理店・配下代理店のユーザーも可能だが、
# agency_id（所属代理店の付け替え）は staff以外のパラメータから除去する（権限昇格防止）。
class Admin::SalesRepresentativesController < Admin::BaseController
  before_action :set_sales_representative, only: [ :show, :edit, :update, :destroy ]

  def index
    scope = policy_scope(SalesRepresentative).includes(agency: :agency_group).order(:sales_rep_code)
    scope = scope.where("sales_representatives.name ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    scope = scope.where("sales_representatives.sales_rep_code ILIKE :q", q: "%#{params[:sales_rep_code]}%") if params[:sales_rep_code].present?
    if params[:agency_q].present?
      scope = scope.joins(:agency).where("agencies.name ILIKE :q OR agencies.agency_code ILIKE :q", q: "%#{params[:agency_q]}%")
    end
    if params[:group_q].present?
      scope = scope.joins(agency: :agency_group)
                   .where("agency_groups.name ILIKE :q OR agency_groups.group_code ILIKE :q", q: "%#{params[:group_q]}%")
    end
    scope = scope.where(is_active: params[:is_active]) if params[:is_active].present?

    @pagy, @sales_representatives = pagy(scope)
  end

  def show
    authorize @sales_representative
  end

  def new
    @sales_representative = SalesRepresentative.new
    authorize @sales_representative
  end

  def edit
    authorize @sales_representative
  end

  def create
    @sales_representative = SalesRepresentative.new(sales_representative_params)
    authorize @sales_representative

    if @sales_representative.save
      redirect_to admin_sales_representative_path(@sales_representative), notice: "営業担当者を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @sales_representative
    permitted = strip_ownership_params!(sales_representative_params, :agency_id, policy_record: @sales_representative)

    if @sales_representative.update(permitted)
      redirect_to admin_sales_representative_path(@sales_representative), notice: "営業担当者を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @sales_representative

    if @sales_representative.destroy
      redirect_to admin_sales_representatives_path, notice: "営業担当者を削除しました。"
    else
      redirect_to admin_sales_representative_path(@sales_representative),
        alert: @sales_representative.errors.full_messages.to_sentence
    end
  end

  private

  def set_sales_representative
    @sales_representative = SalesRepresentative.find(params[:id])
  end

  def sales_representative_params
    params.require(:sales_representative).permit(
      :agency_id, :sales_rep_code, :name, :email, :is_active,
      :pdf_store_name, :pdf_postal_code, :pdf_prefecture, :pdf_city, :pdf_town,
      :pdf_address_detail, :pdf_phone_number, :pdf_fax_number
    )
  end
end
