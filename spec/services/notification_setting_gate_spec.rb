require "rails_helper"

# R6-1: 個人ごとの通知設定の判定ロジック集約先。デフォルトフォールバック・チャネル独立判定・
# 個人設定を持たない宛先種別（Agency等）の常時許可を検証する。
RSpec.describe NotificationSettingGate, seed_status_catalog: true do
  let!(:user) { create(:user) }
  let!(:agency) { create(:agency) }
  let!(:customer) { create(:customer, agency: agency) }

  describe "設定行が無い場合" do
    it "Userは既定値（app/emailともON）にフォールバックする" do
      expect(described_class.app_enabled?(recipient_type: "User", recipient_id: user.id,
             event_type: NotificationEventType::APPLICATION_RECEIVED)).to be(true)
      expect(described_class.email_enabled?(recipient_type: "User", recipient_id: user.id,
             event_type: NotificationEventType::APPLICATION_RECEIVED)).to be(true)
    end

    it "Customerは既定値（app/emailともON）にフォールバックする" do
      expect(described_class.app_enabled?(recipient_type: "Customer", recipient_id: customer.id,
             event_type: NotificationEventType::APPLICATION_CONFIRMED)).to be(true)
      expect(described_class.email_enabled?(recipient_type: "Customer", recipient_id: customer.id,
             event_type: NotificationEventType::APPLICATION_CONFIRMED)).to be(true)
    end
  end

  describe "設定行がある場合" do
    it "app_enabled/email_enabledをそれぞれ独立に反映する" do
      create(:staff_notification_setting, user: user, event_type: NotificationEventType::APPLICATION_RECEIVED,
             app_enabled: false, email_enabled: true)

      expect(described_class.app_enabled?(recipient_type: "User", recipient_id: user.id,
             event_type: NotificationEventType::APPLICATION_RECEIVED)).to be(false)
      expect(described_class.email_enabled?(recipient_type: "User", recipient_id: user.id,
             event_type: NotificationEventType::APPLICATION_RECEIVED)).to be(true)
    end
  end

  describe "個人設定を持たない宛先種別（Agency/SalesRepresentative等）" do
    it "常に許可する（フェイルオープン。既存の常時通知の挙動を変えない）" do
      expect(described_class.email_enabled?(recipient_type: "Agency", recipient_id: agency.id,
             event_type: NotificationEventType::INQUIRY_CASE_RELATED)).to be(true)
      expect(described_class.app_enabled?(recipient_type: "SalesRepresentative", recipient_id: SecureRandom.uuid,
             event_type: NotificationEventType::INQUIRY_CASE_RELATED)).to be(true)
    end
  end
end
