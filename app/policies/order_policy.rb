# frozen_string_literal: true

# 04 R2完了条件（Column.md §10備考: agency_idは「案件一覧のアクセス制御に使用。代理店ユーザは
# 自代理店の案件のみ参照可能。代理店グループユーザは傘下代理店全案件を参照可能」）。
# CustomerPolicyと同じ理由でcreate?は既定のstaff_scope?のまま（R3の申込トランザクションはform
# セクション経由でPunditを通らない別経路のため、この管理画面CRUDのcreate?とは独立）。
class OrderPolicy < ApplicationPolicy
  include AgencyScoped

  def record_agency_id = record.agency_id
  def record_agency_group_id = record.agency&.agency_group_id

  class Scope < ApplicationPolicy::Scope
    include AgencyScoped::ScopeMethods

    private

    def scope_for_agency
      scope.where(agency_id: user.agency_id)
    end

    def scope_for_agency_group
      scope.joins(:agency).where(agencies: { agency_group_id: user.agency_group_id })
    end
  end
end
