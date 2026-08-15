# ログイン履歴（04 R0-4）。専用テーブルではなくAuditLogをAuthAuditable::AUTH_ACTIONSで
# 絞り込む画面（review-02の指摘どおり。ftlogのLoginHistoriesControllerパターンを踏襲）。
class Admin::LoginHistoriesController < Admin::BaseController
  def index
    @audit_logs = AuditLog.auth_events.recent.limit(200)
  end
end
