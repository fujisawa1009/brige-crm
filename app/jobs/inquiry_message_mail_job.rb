# 問い合わせ・返信のメール送信（04 R4タスク1・メール送信欠落の補完。Laravel SendInquiryMessageJob 移植）。
# InquiryMessage に紐づく宛先を RecipientResolver#expand_for_send で送信用に展開し、宛先ごとに送る。
# NotificationDeliveryJob と同じく「ジョブ内 deliver_now ＋ 宛先単位 rescue」で、1宛先の送信失敗が
# 他宛先の送信を止めないようにする（Laravel の try/catch ログ設計を踏襲）。
class InquiryMessageMailJob < ApplicationJob
  queue_as :default

  def perform(inquiry_message_id)
    message = InquiryMessage.find(inquiry_message_id)
    inquiry = message.inquiry

    message.inquiry_message_recipients.find_each do |recipient|
      # 宛先1件（recipient_group ならメンバー複数）を送信用エントリへ展開する。
      expanded = RecipientResolver.expand_for_send([ { type: recipient.recipient_type, id: recipient.recipient_id } ])

      expanded.each do |entry|
        emails = entry[:emails]
        next if emails.blank?

        # R6-1: 個人ごとの通知設定（E4/E9/E10案件関連の通知）でメール通知をOFFにしている宛先
        # （User/Customer）はスキップする（判定はNotificationSettingGateに集約。Agency/
        # SalesRepresentative/ProductionCompanyは個人設定を持たないため常に許可される）。
        next unless NotificationSettingGate.email_enabled?(
          recipient_type: entry[:type], recipient_id: entry[:id],
          event_type: NotificationEventType::INQUIRY_CASE_RELATED
        )

        to_email  = emails.first
        cc_emails = emails[1..] || []

        begin
          InquiryMailer.message_notification(inquiry, message, to_email, cc_emails: cc_emails).deliver_now

          # 最初に成功した宛先だけ resolved_email に記録する（Laravel踏襲。既に記録済みなら上書きしない）。
          recipient.update!(resolved_email: to_email) if recipient.resolved_email.blank?
        rescue StandardError => e
          # 失敗は握りつぶしてログに残し、次の宛先へ進む（他宛先への送信を止めない）。
          Rails.logger.error(
            "[InquiryMessageMailJob] メール送信失敗 " \
            "inquiry_id=#{inquiry.id} message_id=#{message.id} recipient_id=#{recipient.id} " \
            "to=#{to_email} error=#{e.message}"
          )
        end
      end
    end
  end
end
