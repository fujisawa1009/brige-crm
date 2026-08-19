require "rails_helper"

# R6-1: 個人ごとの通知設定（顧客マイページ側）。2026-08-20 CEO決定＝顧客本人ごとに編集できる。
# idパラメータを持たない単数resourceで常にcurrent_customerの設定のみを読み書きすること、
# 未保存イベントは既定値（app/emailともON）にフォールバックすること、
# 他顧客の設定へ影響しないことを検証する。
RSpec.describe "Mypage::NotificationSettings", type: :request, seed_permission_catalog: true,
                                                seed_status_catalog: true do
  let!(:agency) { create(:agency) }
  let!(:customer_a) { create(:customer, agency: agency) }
  let!(:customer_b) { create(:customer, agency: agency) }

  describe "未ログイン" do
    it "ログイン画面へリダイレクトされる" do
      get mypage_notification_settings_path
      expect(response).to redirect_to(new_customer_session_path)
    end
  end

  describe "顧客Aとしてログイン中" do
    before { sign_in(customer_a, scope: :customer) }

    it "設定していないイベントは既定値（app/emailともON）で表示される" do
      get mypage_notification_settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(NotificationEventType.label_for(NotificationEventType::APPLICATION_CONFIRMED))
    end

    it "更新すると自分のCustomerNotificationSettingが作成される（初回保存のみレコード作成）" do
      expect {
        patch mypage_notification_settings_path, params: {
          notification_settings: {
            NotificationEventType::APPLICATION_CONFIRMED => { app_enabled: "1", email_enabled: "0" }
          }
        }
      }.to change(CustomerNotificationSetting, :count).by(1)

      setting = customer_a.customer_notification_settings
                          .find_by!(event_type: NotificationEventType::APPLICATION_CONFIRMED)
      expect(setting.app_enabled).to be(true)
      expect(setting.email_enabled).to be(false)
      expect(response).to redirect_to(mypage_notification_settings_path)
    end

    it "本人の更新は他顧客のCustomerNotificationSettingを作らない（他人の代理編集は不可）" do
      patch mypage_notification_settings_path, params: {
        notification_settings: {
          NotificationEventType::APPLICATION_CONFIRMED => { app_enabled: "0", email_enabled: "0" }
        }
      }

      expect(customer_b.customer_notification_settings).to be_empty
    end

    it "既存設定を更新しても行は増えない（find_or_initialize_by）" do
      create(:customer_notification_setting, customer: customer_a,
             event_type: NotificationEventType::APPLICATION_CONFIRMED, email_enabled: true)

      expect {
        patch mypage_notification_settings_path, params: {
          notification_settings: {
            NotificationEventType::APPLICATION_CONFIRMED => { app_enabled: "1", email_enabled: "0" }
          }
        }
      }.not_to change(CustomerNotificationSetting, :count)
    end
  end
end
