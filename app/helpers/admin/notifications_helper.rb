# admin/notifications の状態・宛先種別バッジ表示。
module Admin::NotificationsHelper
  STATUS_LABELS = {
    Notification::STATUS_DRAFT => "下書き",
    Notification::STATUS_SCHEDULED => "予約済み",
    Notification::STATUS_SENDING => "送信中",
    Notification::STATUS_SENT => "送信済み",
    Notification::STATUS_FAILED => "失敗"
  }.freeze

  STATUS_BADGE_COLORS = {
    Notification::STATUS_DRAFT => "slate",
    Notification::STATUS_SCHEDULED => "blue",
    Notification::STATUS_SENDING => "amber",
    Notification::STATUS_SENT => "green",
    Notification::STATUS_FAILED => "red"
  }.freeze

  TARGET_LABELS = {
    Notification::TARGET_AGENCY => "代理店",
    Notification::TARGET_CUSTOMER => "顧客"
  }.freeze

  def notification_status_label(status) = STATUS_LABELS.fetch(status, status)

  def notification_status_badge(status)
    badge_tag(notification_status_label(status), color: STATUS_BADGE_COLORS.fetch(status, "slate"))
  end

  def notification_target_label(target_type) = TARGET_LABELS.fetch(target_type, target_type)
end
