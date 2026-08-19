# admin section配下コントローラの共通親。ApplicationControllerの認証・認可ゲートをそのまま継承する。
class Admin::BaseController < ApplicationController
  layout "admin"

  # Pundit標準の安全網（04 R0見直しレビュー残タスク・R5着手前チェックリスト「verify系」）。
  # 従来はCIの認可スキップ検出grep（項目10）のみが「authorize/policy_scope呼び出し漏れ」の防御線
  # だったが、これは文字列マッチのみで脆弱（コメントアウトや変数越しの呼び出しをすり抜ける）。
  # Punditが実行時に確実に検出するこちらを主防御にする。
  #
  # 標準的なPunditの慣習（index=一覧はpolicy_scope、それ以外の個別アクションはauthorize）に
  # 合わせている。admin配下は現状この慣習に厳密に従っており（customers_controller等）、
  # 一部コントローラ（PUNDIT_VERIFICATION_EXEMPT_CONTROLLERS参照）だけが例外。
  # only:/except: :index はRails 7.1+の「callback action存在検証」が全サブクラスに対して
  # 効いてしまい、:indexアクションを持たないコントローラ（例: PermissionManagementController）で
  # AbstractController::ActionNotFoundになる。共通の親クラスで宣言する以上、アクション名の分岐は
  # only:/except:ではなくunless:述語（実行時判定）で行う。
  after_action :verify_authorized, unless: :skip_verify_authorized?
  after_action :verify_policy_scoped, unless: :skip_verify_policy_scoped?

  private

  def skip_verify_authorized?
    pundit_verification_exempt? || action_name == "index"
  end

  def skip_verify_policy_scoped?
    pundit_verification_exempt? || action_name != "index"
  end

  # 代理店スコープの概念を持たない、RBAC（Layer1）のみで守られるシステム管理画面。
  # 個々のコントローラを触らずここで一括除外する（役割による判定。将来これらにも
  # レコード単位の参照制御が必要になった場合は、当該コントローラでauthorize/policy_scopeを
  # 呼ぶよう変更したうえでこの一覧から外すこと）:
  #   - dashboard: 複数リソースの集計表示で単一のpolicy対象を持たない
  #   - login_histories: AuditLogの絞り込みビュー（専用テーブルではない。read-only）
  #   - ip_allowlist_entries: admin(super_admin)専有（RoleSeeder）。代理店スコープ対象外
  #   - permission_management / role_management: SystemPermission/SystemRoleの管理そのもの
  PUNDIT_VERIFICATION_EXEMPT_CONTROLLERS = %w[
    admin/dashboard
    admin/login_histories
    admin/ip_allowlist_entries
    admin/permission_management
    admin/role_management
  ].freeze

  def pundit_verification_exempt?
    PUNDIT_VERIFICATION_EXEMPT_CONTROLLERS.include?(controller_path)
  end

  # 04 R1: 代理店/代理店グループ所属を書き換えるパラメータ（agency_id・agency_group_id等）は、
  # Pundit の参照スコープ判定基準そのものを自己申告で書き換えられてしまう権限昇格の経路になるため、
  # staff（admin/実務運用者。AgencyScoped#staff_scope?）以外からは常に除去する。
  # AgencyPolicy/SalesRepresentativePolicy/UserPolicy の update? が既定でaccessible?（自己編集可）に
  # なっている分、こちらでの防御が必須（コントローラ側とPolicy側の2層防御の一部）。
  # 04 R2追補バグ修正: Order#customer_id/store_idも同じ経路の権限昇格になりうる（代理店ユーザーが
  # 自案件のcustomer_id/store_idを他代理店の顧客・店舗のUUIDに書き換えれば、参照スコープを迂回して
  # 他代理店データに接続を作れてしまう）ため、agency_idと同様に呼び出し側で除去対象へ加えること。
  def strip_ownership_params!(permitted, *keys, policy_record:)
    return permitted if policy(policy_record).staff_scope?

    permitted.except(*keys)
  end
end
