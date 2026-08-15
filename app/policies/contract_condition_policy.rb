# frozen_string_literal: true

# 04 R1・Column.md §6。契約条件は代理店の手数料・支払条件等の商取引条件そのものであり、
# 代理店側の自己編集を許可すると自己有利な条件へ書き換えられてしまうため、update?/destroy?も
# staff_scope?のみに上書きする（index?/show?はAgencyScoped既定のaccessible?のまま=閲覧は許可）。
class ContractConditionPolicy < ApplicationPolicy
  include AgencyScoped

  def update? = staff_scope?
  def destroy? = staff_scope?

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
