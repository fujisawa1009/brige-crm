# admin section配下コントローラの共通親。ApplicationControllerの認証・認可ゲートをそのまま継承する。
class Admin::BaseController < ApplicationController
  private

  # 04 R1: 代理店/代理店グループ所属を書き換えるパラメータ（agency_id・agency_group_id等）は、
  # Pundit の参照スコープ判定基準そのものを自己申告で書き換えられてしまう権限昇格の経路になるため、
  # staff（admin/実務運用者。AgencyScoped#staff_scope?）以外からは常に除去する。
  # AgencyPolicy/SalesRepresentativePolicy/UserPolicy の update? が既定でaccessible?（自己編集可）に
  # なっている分、こちらでの防御が必須（コントローラ側とPolicy側の2層防御の一部）。
  def strip_ownership_params!(permitted, *keys, policy_record:)
    return permitted if policy(policy_record).staff_scope?

    permitted.except(*keys)
  end
end
