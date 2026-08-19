# 個人ごとの通知設定・社内スタッフ用マイページ相当画面（R6-1）。idパラメータを持たない単数resourceで
# 常にcurrent_userを対象にするため、他人の設定を編集する経路は存在しない（Pundit認可はAdmin::BaseController
# のPUNDIT_VERIFICATION_EXEMPT_CONTROLLERSで除外。RBACはRoleSeeder::SELF_SERVICE_CONTROLLERSで
# 全ロールへ一律付与）。
class Admin::NotificationSettingsController < Admin::BaseController
  def show
    @settings_by_event_type = current_user.staff_notification_settings.index_by(&:event_type)
  end

  def update
    NotificationEventType::ALL.each do |event_type|
      values = event_params[event_type]
      next if values.blank?

      attrs = {
        app_enabled:   values[:app_enabled] == "1",
        email_enabled: values[:email_enabled] == "1"
      }

      begin
        current_user.staff_notification_settings
                    .find_or_initialize_by(event_type: event_type)
                    .update!(attrs)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        # 同時更新でユニーク制約に衝突した場合は既存行を取り直して更新する（ftlog踏襲）。
        current_user.staff_notification_settings.find_by!(event_type: event_type).update!(attrs)
      end
    end

    redirect_to admin_notification_settings_path, notice: "通知設定を更新しました。"
  end

  private

  def event_params
    return {} unless params[:notification_settings].is_a?(ActionController::Parameters)

    params[:notification_settings]
  end
end
