# frozen_string_literal: true

# 04 R1・Column.md §7。営業担当者は代理店の日常運用物のため、AgencyScoped既定どおり
# update?/destroy?もaccessible?（自代理店・配下代理店内なら編集・無効化を許可）。
# agency_id の付け替え（他代理店への移設）は Admin::SalesRepresentativesController 側
# （strip_ownership_params!）でstaff以外から防御する。
class SalesRepresentativePolicy < ApplicationPolicy
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
