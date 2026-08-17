require "rails_helper"

# 04 R4タスク2・3: 一斉通知。テンプレート結線（選択時に件名・本文が「コピー」されること＝
# ライブ参照でないこと）と、スケジュール送信ジョブの投入、内部運用専有のRBACを検証する。
RSpec.describe "Admin::Notifications", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                        system_authorization: true do
  include ActiveJob::TestHelper

  let!(:staff_user) { user_with_role("実務運用者") }
  let!(:template) do
    create(:notification_template, template_type: NotificationTemplate::TYPE_NOTIFICATION,
                                   subject: "テンプレ件名", body: "テンプレ本文")
  end

  describe "実務運用者（内部スタッフ）" do
    before { sign_in_with_otp!(staff_user) }

    it "一覧・新規フォームにアクセスできる" do
      get admin_notifications_path
      expect(response).to have_http_status(:ok)
      get new_admin_notification_path
      expect(response).to have_http_status(:ok)
    end

    it "テンプレート選択時、件名・本文がテンプレートからコピーされて保存される" do
      post admin_notifications_path, params: {
        notification: { title: "お知らせ", target_type: Notification::TARGET_AGENCY,
                        notification_template_id: template.id }
      }

      notification = Notification.find_by(title: "お知らせ")
      expect(notification).to be_present
      expect(notification.subject).to eq("テンプレ件名")
      expect(notification.body).to eq("テンプレ本文")
      expect(notification.notification_template_id).to eq(template.id)
    end

    it "コピーであり、テンプレート編集後も送信済み通知の件名・本文は変わらない（ライブ参照でない）" do
      post admin_notifications_path, params: {
        notification: { title: "固定される通知", target_type: Notification::TARGET_AGENCY,
                        notification_template_id: template.id }
      }
      notification = Notification.find_by(title: "固定される通知")

      template.update!(subject: "編集後の件名", body: "編集後の本文")

      expect(notification.reload.subject).to eq("テンプレ件名")
      expect(notification.body).to eq("テンプレ本文")
    end

    it "件名・本文を手入力していればテンプレートで上書きしない" do
      post admin_notifications_path, params: {
        notification: { title: "手入力優先", target_type: Notification::TARGET_AGENCY,
                        subject: "手入力件名", body: "手入力本文", notification_template_id: template.id }
      }

      notification = Notification.find_by(title: "手入力優先")
      expect(notification.subject).to eq("手入力件名")
      expect(notification.body).to eq("手入力本文")
    end

    it "即時送信でNotificationDeliveryJobがenqueueされる" do
      notification = create(:notification)

      expect {
        post schedule_admin_notification_path(notification)
      }.to have_enqueued_job(NotificationDeliveryJob).with(notification.id)
      expect(notification.reload.status).to eq(Notification::STATUS_SCHEDULED)
    end

    it "予約送信で発火時刻付きのジョブがenqueueされる" do
      notification = create(:notification)
      at = 1.day.from_now.change(usec: 0)

      expect {
        post schedule_admin_notification_path(notification), params: { scheduled_at: at.iso8601 }
      }.to have_enqueued_job(NotificationDeliveryJob)
      expect(notification.reload.status).to eq(Notification::STATUS_SCHEDULED)
      expect(notification.scheduled_at).to be_within(1.second).of(at)
    end
  end

  describe "代理店ユーザー（内部運用専有のため到達不可）" do
    let!(:agency) { create(:agency) }
    let!(:agency_user) { user_with_role("代理店用", agency: agency) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧は403" do
      get admin_notifications_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
