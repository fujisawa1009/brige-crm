# admin/notifications の状態・宛先種別バッジ表示。
module Admin::NotificationsHelper
  STATUS_LABELS = {
    Notification::STATUS_DRAFT => "下書き",
    Notification::STATUS_SCHEDULED => "予約済み",
    Notification::STATUS_SENDING => "送信中",
    Notification::STATUS_SENT => "送信済み",
    Notification::STATUS_FAILED => "失敗"
  }.freeze

  STATUS_BADGE_CLASSES = {
    Notification::STATUS_DRAFT => "bg-slate-100 text-slate-600",
    Notification::STATUS_SCHEDULED => "bg-blue-100 text-blue-700",
    Notification::STATUS_SENDING => "bg-amber-100 text-amber-700",
    Notification::STATUS_SENT => "bg-green-100 text-green-700",
    Notification::STATUS_FAILED => "bg-red-100 text-red-700"
  }.freeze

  TARGET_LABELS = {
    Notification::TARGET_AGENCY => "代理店",
    Notification::TARGET_CUSTOMER => "顧客"
  }.freeze

  def notification_status_label(status) = STATUS_LABELS.fetch(status, status)
  def notification_status_badge_class(status) = STATUS_BADGE_CLASSES.fetch(status, "bg-slate-100 text-slate-600")
  def notification_target_label(target_type) = TARGET_LABELS.fetch(target_type, target_type)
end
