# 全コントローラの親（04 R0-5）。ftlogのApplicationControllerを単一テナント化して移植。
# before_action の順序が重要（ftlog踏襲）: 認証 → アクティブ確認 → Current確定 → 認可。
# 認可(authorize_system_permission!)はフェイルクローズ（カタログ未登録・ロール未割当は拒否）。
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend # 04 R2タスク7: 一覧のページネーション基盤

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :set_current_attributes
  before_action :authorize_system_permission!

  helper_method :policy, :policy_scope, :can_access_system_action?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def can_access_system_action?(controller, action, http_method: "GET")
    return false unless user_signed_in?

    SystemPermissionChecker.allowed?(
      user: current_user,
      controller: controller,
      action: action,
      http_method: http_method
    )
  end

  private

  # authorize_system_permission! はauthenticate_user!の後段でのみ発火するため、ここに到達する時点で
  # 常にログイン済み。rootが/admin/dashboardへリダイレクトする構成（config/routes.rb）のため、
  # ftlog踏襲のroot_pathへのリダイレクトは「権限ゼロのユーザーがdashboardでも拒否される」ケースで
  # 無限リダイレクトになりうる。素直に403を返すことで、R0完了条件が求める
  # 「権限剥奪で403相当になる」を文字どおり満たしつつループも避ける。
  def user_not_authorized
    render plain: "この操作を行う権限がありません。", status: :forbidden
  end

  def authorize_system_permission!
    return if skip_system_permission_authorization?
    return if SystemPermissionChecker.allowed?(
      user: current_user,
      controller: controller_path,
      action: action_name,
      http_method: request.request_method
    )

    raise Pundit::NotAuthorizedError
  end

  def set_current_attributes
    Current.user       = current_user
    Current.ip_address = request.remote_ip
    Current.request_id = request.request_id
  end

  # devise系コントローラ（ログイン・パスワード再設定・OTP入力）は認証前後の状態遷移そのものが
  # 目的のためRBACカタログの対象外にする（ftlog踏襲）。
  #
  # 03§8-2決定(b): form名前空間（受注入力。R3で追加）はauthorize_system_permission!を完全スキップし、
  # 独自FormAuthミドルウェア（R3で実装）のみで保護する。理由: SalesRepresentativeはDevise対象外で
  # user.staff?/customer?のようなSTI判定に乗らないため、checker拡張よりskip判定の方が責務分離が明快
  # （03§8-2「認可統合」決定）。R0時点ではform配下のコントローラがまだ存在しないため実質no-opだが、
  # 判定ロジックの置き場所だけ用意しておく。
  def skip_system_permission_authorization?
    devise_controller? ||
      self.class.name.start_with?("Users::") ||
      controller_path.start_with?("form/")
  end
end
