# 個人ごとの通知設定・顧客マイページ側（R6-1。2026-08-20 CEO決定＝顧客本人ごとに編集できるようにする）。
# idパラメータを持たない単数resourceで常にcurrent_customerを対象にするため、他顧客の設定を編集する
# 経路は存在しない。RBACはSystemPermissionChecker#mypage_allowed?がカタログ登録済みルートである
# ことのみを見る既定の仕組みに乗るため、Admin側のようなロール別付与は不要（Mypage::DashboardController
# と同じ扱い）。
class Mypage::NotificationSettingsController < Mypage::BaseController
  def show
    @settings_by_event_type = current_customer.customer_notification_settings.index_by(&:event_type)
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
        current_customer.customer_notification_settings
                        .find_or_initialize_by(event_type: event_type)
                        .update!(attrs)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        # 同時更新でユニーク制約に衝突した場合は既存行を取り直して更新する（ftlog踏襲）。
        current_customer.customer_notification_settings.find_by!(event_type: event_type).update!(attrs)
      end
    end

    redirect_to mypage_notification_settings_path, notice: "通知設定を更新しました。"
  end

  private

  def event_params
    return {} unless params[:notification_settings].is_a?(ActionController::Parameters)

    params[:notification_settings]
  end
end
