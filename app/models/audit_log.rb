# 監査ログ本体（04 R0-7）。単一テナントのため organization_id/project_id は持たない。
# admin/login_histories はこのテーブルを AuthAuditable::AUTH_ACTIONS で絞り込む画面
# （review-02の指摘どおり、専用テーブルではなくAuditLogの絞り込みビュー）。
class AuditLog < ApplicationRecord
  validates :user_id,       presence: true
  validates :user_type,     presence: true
  validates :action,        presence: true
  validates :resource_type, presence: true

  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }
  scope :recent,       -> { order(created_at: :desc) }
  scope :auth_events,  -> { where(action: AuthAuditable::AUTH_ACTIONS) }
end
