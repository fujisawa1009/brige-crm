# 申込完了時の顧客向け確認メール（04 R3タスク5。Laravel現行「申込確認メール」相当。
# 03§8-2のformセクションはDeviseに乗らないためApplicationMailer本体とは別クラスに分ける。
# 実送信先はmailpit経由でよい旨がタスク定義に明記されているため、SMTP接続先は
# config/environments配下の既定設定に委ねる）。
class Form::ApplicationMailer < ApplicationMailer
  def confirmation(application)
    @application = application
    @customer    = application.customer
    @order       = application.order

    return if @customer.email.blank?
    # R6-1: 個人ごとの通知設定（E2申込確認）で顧客本人がメール通知をOFFにしている場合は送らない
    # （判定はNotificationSettingGateに集約）。
    return unless NotificationSettingGate.email_enabled?(
      recipient_type: "Customer", recipient_id: @customer.id,
      event_type: NotificationEventType::APPLICATION_CONFIRMED
    )

    mail(to: @customer.email, subject: "[brige-crm] お申込みを受け付けました")
  end
end
