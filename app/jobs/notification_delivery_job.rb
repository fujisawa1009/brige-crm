# 一斉通知の実送信（04 R4タスク3。Solid Queueのdelayed job。Notification#schedule!が
# `.set(wait_until: scheduled_at)`で発火時刻を予約する＝Laravel現行の「予約通知配信(毎分)」の
# ポーリングが不要になる）。
#
# 宛先1件ごとにNotificationRecipientを作成し、送信成否を記録する（一部宛先の失敗が全体を止めない
# ようbegin/rescueを宛先単位にする。Notification#total_count等の集計はここで更新する）。
class NotificationDeliveryJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find(notification_id)
    notification.update!(status: Notification::STATUS_SENDING)

    # R6-1: 個人ごとの通知設定（E13一斉通知）でメール通知をOFFにしている顧客は宛先から除外する
    # （判定はNotificationSettingGateに集約。Agency宛は個人設定を持たないため常に残る。除外された
    # 宛先はNotificationRecipientを作らない＝メールアドレス不備で除外する既存のresolve_recipients
    # と同じ「送れたはずの宛先」だけを集計対象にする方針を踏襲する）。
    recipients = notification.resolve_recipients.select do |entry|
      NotificationSettingGate.email_enabled?(
        recipient_type: entry.fetch(:recipient_type), recipient_id: entry.fetch(:recipient_id),
        event_type: NotificationEventType::BROADCAST_NOTIFICATION
      )
    end
    success = 0
    failed  = 0

    recipients.each do |entry|
      recipient_record = notification.notification_recipients.create!(
        recipient_type: entry.fetch(:recipient_type),
        recipient_id:   entry.fetch(:recipient_id),
        email:          entry.fetch(:email)
      )

      begin
        NotificationMailer.broadcast(notification, entry.fetch(:email)).deliver_now
        recipient_record.mark_sent!
        success += 1
      rescue StandardError => e
        recipient_record.mark_failed!(e.message)
        failed += 1
      end
    end

    notification.update!(
      status:        failed.positive? && success.zero? ? Notification::STATUS_FAILED : Notification::STATUS_SENT,
      sent_at:       Time.current,
      total_count:   recipients.size,
      success_count: success,
      failed_count:  failed
    )
  end
end
