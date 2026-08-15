# 監査ログ本体（04 R0-7）。単一テナントのため organization_id/project_id は持たない。
# admin/login_histories はこのテーブルを AuthAuditable::AUTH_ACTIONS で絞り込む画面
# （review-02の指摘どおり、専用テーブルではなくAuditLogの絞り込みビュー）。
# == Schema Information
#
# Table name: audit_logs
#
#  id             :uuid             not null, primary key
#  action         :string           not null
#  changes_after  :jsonb
#  changes_before :jsonb
#  ip_address     :string
#  metadata       :jsonb
#  resource_label :string
#  resource_type  :string           not null
#  source         :string
#  user_type      :string           not null
#  created_at     :datetime         not null
#  request_id     :string
#  resource_id    :uuid
#  user_id        :uuid             not null
#
# Indexes
#
#  index_audit_logs_on_action                   (action)
#  index_audit_logs_on_created_at               (created_at)
#  index_audit_logs_on_resource_and_created_at  (resource_type,resource_id,created_at DESC)
#  index_audit_logs_on_user_id                  (user_id)
#
class AuditLog < ApplicationRecord
  validates :user_id,       presence: true
  validates :user_type,     presence: true
  validates :action,        presence: true
  validates :resource_type, presence: true

  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }
  scope :recent,       -> { order(created_at: :desc) }
  scope :auth_events,  -> { where(action: AuthAuditable::AUTH_ACTIONS) }
end
