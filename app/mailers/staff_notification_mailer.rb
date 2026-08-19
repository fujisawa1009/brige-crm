# 申込完了のスタッフ向け通知（04 R3タスク5）。R4で本格実装予定のSystemNotification基盤（アプリ内
# 通知・Solid Cableリアルタイム配信）はまだ存在しないため、タスク指示どおり「まずは監査ログ記録＋
# メール通知だけ」の最小実装にする（過剰実装を避ける）。
#
# 宛先は実務運用者ロール（SystemRole）に所属する全Userのメールアドレス（社内の日常業務担当者= 04
# R2までの権限マトリクスで新規申込の一次対応を担う想定のロール）。該当ユーザーが0件の場合は
# 送信をスキップする（宛先の無いメールをdeliver_laterしても失敗するだけのため）。
#
# R6-1: 個人ごとの通知設定（E1申込受付）で email_enabled=false にしているユーザーは宛先から除外する
# （判定はNotificationSettingGateに集約。1通のメールに複数toを積む方式のため、ここで宛先を
# 絞り込んだ後に1回だけmailを組み立てる）。
class StaffNotificationMailer < ApplicationMailer
  def new_application(order)
    @order    = order
    @customer = order.customer
    recipients = staff_recipient_emails
    return if recipients.empty?

    mail(to: recipients, subject: "[brige-crm] 新規申込がありました（#{order.order_number}）")
  end

  private

  def staff_recipient_emails
    User.joins(:system_roles).where(system_roles: { name: "実務運用者" }).where(is_active: true)
        .distinct
        .reject { |user| user.email.blank? }
        .select do |user|
          NotificationSettingGate.email_enabled?(
            recipient_type: "User", recipient_id: user.id,
            event_type: NotificationEventType::APPLICATION_RECEIVED
          )
        end
        .map(&:email)
  end
end
