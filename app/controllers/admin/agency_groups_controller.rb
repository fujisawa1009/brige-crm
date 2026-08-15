# 代理店グループ管理（04 R1・Column.md §1）。作成・更新・削除は staff（admin/実務運用者）のみ
# （AgencyGroupPolicy参照）。代理店グループユーザーは自グループのみ index/show 可。
class Admin::AgencyGroupsController < Admin::BaseController
  before_action :set_agency_group, only: [ :show, :edit, :update, :destroy ]

  def index
    @agency_groups = policy_scope(AgencyGroup).order(:name)
  end

  def show
    authorize @agency_group
  end

  def new
    @agency_group = AgencyGroup.new
    authorize @agency_group
  end

  def edit
    authorize @agency_group
  end

  def create
    @agency_group = AgencyGroup.new(agency_group_params)
    authorize @agency_group

    if @agency_group.save
      redirect_to admin_agency_group_path(@agency_group), notice: "代理店グループを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @agency_group

    if @agency_group.update(agency_group_params)
      redirect_to admin_agency_group_path(@agency_group), notice: "代理店グループを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @agency_group

    if @agency_group.destroy
      redirect_to admin_agency_groups_path, notice: "代理店グループを削除しました。"
    else
      redirect_to admin_agency_group_path(@agency_group), alert: @agency_group.errors.full_messages.to_sentence
    end
  end

  private

  def set_agency_group
    @agency_group = AgencyGroup.find(params[:id])
  end

  def agency_group_params
    params.require(:agency_group).permit(
      :name, :service_type, :group_code, :contact_email, :bridge_plan_display_type, :csv_download_visible
    )
  end
end
