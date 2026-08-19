# 個人ごとの通知設定（R6-1）が対象とするイベント種別の初期カタログ。
#
# requirements/design/notification-matrix.md で確定済みのE番号に対応する（E6決済失敗は「通知不要」
# 決定済みのため対象外。04-rails-implementation-plan.md R6-1参照）。StaffNotificationSetting /
# CustomerNotificationSetting の両方から共通で参照する単一のソース・オブ・トゥルース。
#
# E4/E9/E10（後確・制作対応・検収コール・アフター問合せ）は実装上1つの配信経路（RecipientResolver /
# InquiryNotifier / InquiryMessageMailJob）にまとまっているため、通知設定でも1イベント種別
# （INQUIRY_CASE_RELATED）に統合する（カテゴリ別に分けると設定UIが4倍に膨らむ割に業務上の使い分け
# 要求が今のところ無いため。カテゴリ別に分けたくなった場合は event_type を category 別に増やせばよく、
# 既存設定行はマイグレーション不要でそのまま残せる設計）。
#
# E3（不備差戻し）・E5（契約確定）はR5（契約フロー）の配信ロジックが未実装のため、現時点では
# カタログに登録するのみで実際の配信箇所への組み込みは行わない（R5実装時にNotificationSettingGate
# 経由で組み込むこと。R6-1はR5の契約・決済フローに一切触れない指示のため、配信ロジック側は対象外）。
module NotificationEventType
  APPLICATION_RECEIVED   = "application_received"   # E1 申込受付
  APPLICATION_CONFIRMED  = "application_confirmed"   # E2 申込確認
  DEFICIENCY_RETURNED    = "deficiency_returned"     # E3 不備差戻し（R5で配信実装予定）
  INQUIRY_CASE_RELATED   = "inquiry_case_related"    # E4/E9/E10 案件関連の通知（後確/制作対応/検収コール/アフター問合せ）
  CONTRACT_CONFIRMED     = "contract_confirmed"      # E5 契約確定（R5で配信実装予定）
  BROADCAST_NOTIFICATION = "broadcast_notification"  # E13 一斉通知

  ALL = [
    APPLICATION_RECEIVED,
    APPLICATION_CONFIRMED,
    DEFICIENCY_RETURNED,
    INQUIRY_CASE_RELATED,
    CONTRACT_CONFIRMED,
    BROADCAST_NOTIFICATION
  ].freeze

  LABELS = {
    APPLICATION_RECEIVED   => "申込受付（E1）",
    APPLICATION_CONFIRMED  => "申込確認（E2）",
    DEFICIENCY_RETURNED    => "不備差戻し（E3）",
    INQUIRY_CASE_RELATED   => "案件関連の通知（E4/E9/E10・後確/制作対応/検収コール/アフター問合せ）",
    CONTRACT_CONFIRMED     => "契約確定（E5）",
    BROADCAST_NOTIFICATION => "一斉通知（E13）"
  }.freeze

  def self.label_for(event_type)
    LABELS.fetch(event_type, event_type)
  end
end
