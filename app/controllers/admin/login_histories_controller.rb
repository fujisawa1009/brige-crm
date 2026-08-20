# ログイン履歴（04 R0-4）。専用テーブルではなくAuditLogをAuthAuditable::AUTH_ACTIONSで
# 絞り込む画面（review-02の指摘どおり。ftlogのLoginHistoriesControllerパターンを踏襲）。
class Admin::LoginHistoriesController < Admin::BaseController
  def index
    scope = AuditLog.auth_events.recent
    scope = scope.where(action: params[:event_type]) if params[:event_type].present?
    scope = scope.where("resource_label ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

    # ページネーション追加にあたり、従来の「直近200件」上限は**撤廃**する
    # （CEO指示 2026-08-20 タスク6・採用方針）。理由:
    #   1. この画面は監査用途であり、201件目以降が画面から一切たどれない状態は
    #      「黙って切り捨てる」という監査機能として最も避けたい失敗の仕方になる。
    #   2. 上限の目的だった「無制限スキャンの回避」は、ページネーションのほうが上手く果たす。
    #      pagy は LIMIT 30 OFFSET n を発行するため、テーブルが何万件でも1リクエストで
    #      読む行数は30件で頭打ちになる。従来は毎回200行を読んでいたので実質的に軽くなる。
    #   3. 並び替え・絞り込みに使う列にはインデックスがある
    #      （index_audit_logs_on_created_at / index_audit_logs_on_action）。
    # 残る懸念は pagy の総件数 COUNT と、深いページでの OFFSET の劣化。監査ログが十分に
    # 育ったら pagy_countless（総件数を出さない方式）への切替を検討すること。
    # created_at は同一秒に複数件並びうるため、ページ送りの順序を安定させる第2キーに id を添える。
    @pagy, @audit_logs = pagy(scope.order(id: :asc))
  end
end
