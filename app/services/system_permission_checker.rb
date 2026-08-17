# エンドポイントRBAC・判定ロジック（04 R0-5・04 R4タスク5でmypage(Customer)分岐を追加）。
# ftlogのSystemPermissionCheckerを単一テナント化。
#
# ftlog原本は user.staff?/user.customer? でsection分岐していた。brige-crmはR0時点ではUserのみ
# （admin section）だったが、R4でCustomer（mypage section）を追加する。form sectionは
# ApplicationController側で完全スキップ（03§8-2決定b）されるためこのクラスに到達しない。
#
# 03§3「section の割当」決定: mypage/form は「その認証系統でログイン済みなら通れる」固定運用
# （ロール×権限の割当対象にしない。営業担当者・顧客はロールを持たないアクターのため）。
# admin(User)がロール保有チェックまで行うのと異なり、mypage(Customer)は
# 「SystemPermissionカタログにmypage sectionの行として存在し有効か」だけを見る
# （04 R4タスク5「mypage sectionのRBAC統合方式...Customerがそこに正しく乗るように」の実装。
# formのような完全スキップとは違い、必ずこのクラスを経由する点に注意）。
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

    case user
    when User
      return true if user.super_admin?

      admin_allowed?
    when Customer
      mypage_allowed?
    else
      false # 未知の主体（例: SalesRepresentative）は常に拒否。form section同様、専用concernで守ること
    end
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

  # mypageはロール割当が存在しない認証系統のため、カタログに有効な行があること自体を許可条件とする
  # （SystemPermissionSyncServiceがmypage/配下のルートを自動登録済みである前提。フェイルクローズは
  # 「ルート未登録・無効化されている＝拒否」で担保される）。
  def mypage_allowed?
    matching_permissions.where(section: "mypage").exists?
  end

  def matching_permissions
    SystemPermission.enabled.where(
      controller:  controller,
      action:      action,
      http_method: [ http_method, "ALL" ]
    )
  end
end
