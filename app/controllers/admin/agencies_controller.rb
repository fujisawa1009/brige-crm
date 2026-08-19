# 代理店管理（04 R1・Column.md §2）。作成・削除は staff（admin/実務運用者）のみ（AgencyPolicy参照）。
# 更新は自代理店・配下代理店のユーザーも可能だが、agency_group_id（所属グループの付け替え）は
# staff以外のパラメータから除去する（strip_ownership_params!。権限昇格防止）。
class Admin::AgenciesController < Admin::BaseController
  before_action :set_agency, only: [ :show, :edit, :update, :destroy ]

  def index
    scope = policy_scope(Agency).includes(:agency_group, :products).order(:name)
    scope = scope.where("agencies.name ILIKE :q OR agencies.agency_code ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    scope = scope.where("agencies.contact_person ILIKE :q", q: "%#{params[:contact_person]}%") if params[:contact_person].present?
    if params[:email].present?
      scope = scope.where(
        "agencies.email_1 ILIKE :q OR agencies.email_2 ILIKE :q OR agencies.email_3 ILIKE :q OR agencies.email_4 ILIKE :q OR agencies.email_5 ILIKE :q",
        q: "%#{params[:email]}%"
      )
    end
    if params[:group_q].present?
      scope = scope.joins(:agency_group)
                   .where("agency_groups.name ILIKE :q OR agency_groups.group_code ILIKE :q", q: "%#{params[:group_q]}%")
    end
    if params[:product_id].present?
      scope = scope.joins(:agency_products).where(agency_products: { product_id: params[:product_id] }).distinct
    end
    scope = scope.where(electronic_contract_enabled: tri_state_param(params[:electronic_contract_enabled])) if params[:electronic_contract_enabled].present?
    scope = scope.where(csv_download_visible: tri_state_param(params[:csv_download_visible])) if params[:csv_download_visible].present?

    @pagy, @agencies = pagy(scope)
    @products = Product.order(:name)
  end

  def show
    authorize @agency
  end

  def new
    @agency = Agency.new
    authorize @agency
  end

  def edit
    authorize @agency
  end

  def create
    @agency = Agency.new(agency_params)
    authorize @agency

    if @agency.save
      redirect_to admin_agency_path(@agency), notice: "代理店を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @agency
    permitted = strip_ownership_params!(agency_params, :agency_group_id, policy_record: @agency)

    if @agency.update(permitted)
      redirect_to admin_agency_path(@agency), notice: "代理店を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @agency

    if @agency.destroy
      redirect_to admin_agencies_path, notice: "代理店を削除しました。"
    else
      redirect_to admin_agency_path(@agency), alert: @agency.errors.full_messages.to_sentence
    end
  end

  private

  # 電子契約フラグ・CSVダウンロード表示は nullable boolean（未設定/true/false）のため、
  # セレクトの "null" は明示的にnilを、"true"/"false"はそれぞれの真偽値を返す。
  def tri_state_param(value)
    return nil if value == "null"

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def set_agency
    @agency = Agency.find(params[:id])
  end

  def agency_params
    params.require(:agency).permit(
      :agency_group_id, :name, :agency_code, :contact_person,
      :email_1, :email_2, :email_3, :email_4, :email_5,
      :electronic_contract_enabled, :csv_download_visible
    )
  end
end
