# mypage section配下コントローラの共通親（04 R4タスク5・03§3決定Cのmypage区分）。
#
# ApplicationControllerのUser向けDevise認証(authenticate_user!)はCustomerには使えないため、
# skip_before_actionしてauthenticate_customer!に差し替える（Form::BaseController + FormAuthenticatable
# と同じ「親の想定を上書きする」パターンだが、mypageはDeviseスコープを使うため独自concernは不要）。
#
# authorize_system_permission!も上書きする: 親クラスはcurrent_user（Userスコープ）を見るため、
# mypageリクエストでは常にnil→即拒否になってしまう。SystemPermissionCheckerはCustomer分岐を
# 持つ（04 R4タスク5でapp/services/system_permission_checker.rbに追加済み）ため、
# ここではuser:に current_customer を渡すだけでよい（04 R4タスク5「mypage sectionのRBAC統合方式」
# =formのような完全スキップではなくSystemPermissionCheckerを経由する方式、の実装）。
class Mypage::BaseController < ApplicationController
  skip_before_action :authenticate_user!
  prepend_before_action :authenticate_customer!

  private

  def authorize_system_permission!
    return if SystemPermissionChecker.allowed?(
      user: current_customer,
      controller: controller_path,
      action: action_name,
      http_method: request.request_method
    )

    raise Pundit::NotAuthorizedError
  end
end
