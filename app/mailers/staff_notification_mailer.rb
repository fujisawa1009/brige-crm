# 申込完了のスタッフ向け通知（04 R3タスク5）。R4で本格実装予定のSystemNotification基盤（アプリ内
# 通知・Solid Cableリアルタイム配信）はまだ存在しないため、タスク指示どおり「まずは監査ログ記録＋
# メール通知だけ」の最小実装にする（過剰実装を避ける）。
#
# 宛先は実務運用者ロール（SystemRole）に所属する全Userのメールアドレス（社内の日常業務担当者= 04
# R2までの権限マトリクスで新規申込の一次対応を担う想定のロール）。該当ユーザーが0件の場合は
# 送信をスキップする（宛先の無いメールをdeliver_laterしても失敗するだけのため）。
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
        .distinct.pluck(:email).reject(&:blank?)
  end
end
