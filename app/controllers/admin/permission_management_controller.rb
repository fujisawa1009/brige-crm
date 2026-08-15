# 権限マトリクスUI（04 R0-5）。ftlogのPermissionManagementControllerを単一テナント化して移植。
# staff/customerの2区分だったftlogに対し、brige-crmはadmin/form/mypageの3区分だが、
# 編集対象はadmin sectionのみ（03§3「ロール割当の編集対象はadmin sectionのみ」）。
class Admin::PermissionManagementController < Admin::BaseController
  def show
    load_permission_matrix
  end

  def update
    update_role_permissions!
    redirect_to admin_permission_management_path, notice: "権限設定を保存しました。"
  end

  def sync
    result = SystemPermissionSyncService.call
    redirect_to admin_permission_management_path,
                notice: "権限を同期しました（追加: #{result.created} / 更新: #{result.updated} / 無効化: #{result.disabled} / 有効: #{result.active}）。"
  end

  private

  def load_permission_matrix
    @roles = SystemRole.order(Arel.sql("COALESCE(position, 99999), system DESC, name ASC"))
    @permissions = SystemPermission.includes(:system_roles).admin
                     .order(:controller, :action, :http_method, :path)
  end

  def update_role_permissions!
    roles = SystemRole.order(:name).to_a
    permissions = SystemPermission.admin.order(:controller, :action, :http_method, :path).to_a
    selected_role_ids_by_permission_id = selected_role_ids_by_permission_id(permissions, roles)
    admin_roles, editable_roles = roles.partition(&:admin?)

    SystemRolePermission.transaction do
      SystemRolePermission.where(system_role: admin_roles).delete_all if admin_roles.any?

      permissions.each do |permission|
        editable_roles.each do |role|
          role_permission = SystemRolePermission.find_by(system_role: role, system_permission: permission)
          should_allow = selected_role_ids_by_permission_id.fetch(permission.id, []).include?(role.id)

          if should_allow
            SystemRolePermission.find_or_create_by!(system_role: role, system_permission: permission)
          else
            role_permission&.destroy!
          end
        end
      end
    end
  end

  def selected_role_ids_by_permission_id(permissions, roles)
    editable_role_ids = roles.reject(&:admin?).map(&:id)
    permission_param_keys = permissions.map { |permission| permission.id.to_s }
    submitted_permissions = permitted_permissions(permission_param_keys)

    submitted_permissions.each_with_object({}) do |(permission_id, role_ids), result|
      result[permission_id] = Array(role_ids) & editable_role_ids
    end
  end

  def permitted_permissions(permission_param_keys)
    params
      .permit(permissions: permission_param_keys.index_with { [] })
      .to_h
      .fetch("permissions", {})
  end
end
