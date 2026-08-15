# エンドポイントRBAC・判定ロジック（04 R0-5）。ftlogのSystemPermissionCheckerを単一テナント化。
#
# ftlog原本は user.staff?/user.customer? でsection分岐していたが、brige-crmはR0時点でUserモデル
# しか存在せず、admin sectionのみ実際に判定する。form sectionはApplicationController側で
# 完全スキップ（03§8-2決定b）されるためこのクラスに到達しない。mypage section（R4のCustomer）は
# 将来ここに分岐を追加する（決定b同様、Customer用のchecker拡張はR4で行う。現時点ではfalseを返す
# ことで「未実装機能への到達=拒否」というフェイルクローズを保つ）。
class SystemPermissionChecker
  def self.allowed?(user:, controller:, action:, http_method:)
    new(user: user, controller: controller, action: action, http_method: http_method).allowed?
  end

  def initialize(user:, controller:, action:, http_method:)
    @user        = user
    @controller  = controller
    @action      = action
    @http_method = http_method
  end

  def allowed?
    return false unless user.present?
    return false unless user.is_a?(User) # mypage(Customer)等はR4で別途対応

    return true if user.super_admin?

    admin_allowed?
  end

  private

  attr_reader :user, :controller, :action, :http_method

  def admin_allowed?
    permissions = matching_permissions.where(section: "admin")
    return false if permissions.empty?

    SystemRolePermission
      .joins(:system_role)
      .where(system_role: user.system_roles, system_permission: permissions)
      .exists?
  end

  def matching_permissions
    SystemPermission.enabled.where(
      controller:  controller,
      action:      action,
      http_method: [http_method, "ALL"]
    )
  end
end
