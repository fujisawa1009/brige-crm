# ログイン履歴（04 R0-4）。専用テーブルではなくAuditLogをAuthAuditable::AUTH_ACTIONSで
# 絞り込む画面（review-02の指摘どおり。ftlogのLoginHistoriesControllerパターンを踏襲）。
class Admin::LoginHistoriesController < Admin::BaseController
  def index
    scope = AuditLog.auth_events.recent
    scope = scope.where(action: params[:event_type]) if params[:event_type].present?
    scope = scope.where("resource_label ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

    # 専用テーブルを持たず監査ログ全体から絞り込む画面のため、無制限スキャンを避けるべく
    # 直近200件に上限を設ける（review-02の指摘どおりの元設計を踏襲）。フィルタは上限適用前に効かせる。
    @audit_logs = scope.limit(200)
  end
end
