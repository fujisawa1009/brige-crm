# 一斉通知の実送信メール（04 R4タスク3。NotificationDeliveryJobから呼ぶ）。
class NotificationMailer < ApplicationMailer
  def broadcast(notification, to_email)
    @notification = notification

    mail(to: to_email, subject: notification.subject.presence || notification.title)
  end
end
