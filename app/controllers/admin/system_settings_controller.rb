# システム設定（R6-3・2026-08-20 CEO決定）。brige-crmはシングルテナントのため「組織単位」の設定は
# 無く、代わりにアプリ全体で1行のみのシングルトン設定画面として実装する。
# admin/ip_allowlist_entries・admin/permission_management等と同じく「テナントスコープの概念を持たない、
# RBAC（Layer1）のみで守られるシステム管理画面」（Admin::BaseController::PUNDIT_VERIFICATION_EXEMPT_CONTROLLERS
# 参照）で、Pundit Policyは持たない。RoleSeeder::SYSTEM_ADMIN_ONLY_CONTROLLERSによりadmin(super_admin)
# 専有（ip_allowlist_entries同様、実務運用者以下に開放すると添付上限を自己申告で緩められてしまうため）。
# idパラメータを持たない単数resourceで、常に唯一のSystemSettingレコードを対象にする
# （admin/notification_settingsと同じ形。ただし対象はcurrent_userではなくSystemSetting.currentの1行）。
class Admin::SystemSettingsController < Admin::BaseController
  def show
    @system_setting = SystemSetting.current
  end

  def update
    @system_setting = SystemSetting.current

    if @system_setting.update(system_setting_params)
      redirect_to admin_system_settings_path, notice: "システム設定を更新しました。"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def system_setting_params
    params.require(:system_setting).permit(:inquiry_attachment_max_count, :inquiry_attachment_max_size_mb)
  end
end
