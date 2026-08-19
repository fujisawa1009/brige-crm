require "rails_helper"

# R6-1: 個人ごとの通知設定（社内スタッフ用マイページ相当画面）。
# idパラメータを持たない単数resourceで常にcurrent_userの設定のみを読み書きすること、
# 未保存イベントは既定値（app/emailともON）にフォールバックすること、
# 全ロールが到達できる自己サービス画面であることを検証する。
RSpec.describe "Admin::NotificationSettings", type: :request, seed_permission_catalog: true,
                                               system_authorization: true do
  let!(:staff_user) { user_with_role("実務運用者") }

  describe "未ログイン" do
    it "ログイン画面へリダイレクトされる" do
      get admin_notification_settings_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "実務運用者としてログイン中" do
    before { sign_in_with_otp!(staff_user) }

    it "設定していないイベントは既定値（app/emailともON）で表示される" do
      get admin_notification_settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(NotificationEventType.label_for(NotificationEventType::APPLICATION_RECEIVED))
    end

    it "更新すると自分のStaffNotificationSettingが作成される（初回保存のみレコード作成）" do
      expect {
        patch admin_notification_settings_path, params: {
          notification_settings: {
            NotificationEventType::APPLICATION_RECEIVED => { app_enabled: "1", email_enabled: "0" }
          }
        }
      }.to change(StaffNotificationSetting, :count).by(1)

      setting = staff_user.staff_notification_settings.find_by!(event_type: NotificationEventType::APPLICATION_RECEIVED)
      expect(setting.app_enabled).to be(true)
      expect(setting.email_enabled).to be(false)
      expect(response).to redirect_to(admin_notification_settings_path)
    end

    it "既存設定を更新しても行は増えない（find_or_initialize_by）" do
      create(:staff_notification_setting, user: staff_user,
             event_type: NotificationEventType::APPLICATION_RECEIVED, email_enabled: true)

      expect {
        patch admin_notification_settings_path, params: {
          notification_settings: {
            NotificationEventType::APPLICATION_RECEIVED => { app_enabled: "1", email_enabled: "0" }
          }
        }
      }.not_to change(StaffNotificationSetting, :count)

      expect(staff_user.staff_notification_settings.find_by!(event_type: NotificationEventType::APPLICATION_RECEIVED)
               .email_enabled).to be(false)
    end
  end

  describe "本人のみ変更可能（他ユーザーの設定に影響しない）" do
    let!(:other_staff) { user_with_role("実務運用者") }

    before { sign_in_with_otp!(staff_user) }

    it "自分の更新は他ユーザーのStaffNotificationSettingを作らない" do
      patch admin_notification_settings_path, params: {
        notification_settings: {
          NotificationEventType::APPLICATION_RECEIVED => { app_enabled: "0", email_enabled: "0" }
        }
      }

      expect(other_staff.staff_notification_settings).to be_empty
    end
  end

  # RBAC（SELF_SERVICE_CONTROLLERS）: ロールを問わず全員が自分の通知設定に到達できる。
  %w[admin 実務運用者 代理店グループ用 代理店用].each do |role_name|
    it "#{role_name}ロールでも通知設定画面に到達できる" do
      agency = create(:agency)
      user =
        case role_name
        when "代理店用" then user_with_role(role_name, agency: agency)
        when "代理店グループ用" then user_with_role(role_name, agency_group: agency.agency_group)
        else user_with_role(role_name)
        end

      sign_in_with_otp!(user)
      get admin_notification_settings_path
      expect(response).to have_http_status(:ok)
    end
  end
end
