# ロール管理UI（04 R0-5）。ftlogのRoleManagementControllerを単一テナント化して移植。
class Admin::RoleManagementController < Admin::BaseController
  before_action :set_role, only: [:show, :edit, :update, :destroy]

  def index
    @roles = SystemRole.order(Arel.sql("COALESCE(position, 99999), system DESC, name ASC"))
  end

  def new
    @new_role = SystemRole.new
  end

  def show; end

  def edit; end

  def create
    @new_role = SystemRole.new(role_params.merge(system: false))
    @new_role.position = (SystemRole.maximum(:position) || 0) + 1

    if @new_role.save
      redirect_to admin_role_management_index_path, notice: "ロールを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @role.update(update_role_params)
      redirect_to admin_role_management_index_path, notice: "ロールを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @role.destroy
      redirect_to admin_role_management_index_path, notice: "ロールを削除しました。"
    else
      redirect_to admin_role_management_index_path, alert: @role.errors.full_messages.to_sentence
    end
  end

  def reorder
    ids = Array(params[:ids]).select(&:present?)
    SystemRole.transaction do
      ids.each_with_index { |id, index| SystemRole.where(id: id).update_all(position: index + 1) }
    end
    head :ok
  end

  private

  def set_role
    @role = SystemRole.find(params[:id])
  end

  def role_params
    params.require(:system_role).permit(:name, :display_name, :description)
  end

  def update_role_params
    permitted = params.require(:system_role).permit(:name, :display_name, :description)
    @role.system? ? permitted.except(:name) : permitted
  end
end
