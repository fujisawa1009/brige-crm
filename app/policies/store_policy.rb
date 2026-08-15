# frozen_string_literal: true

# 04 R2完了条件。Storeはagency_idを直接持たない（Column.md §9。customer経由で代理店に属する）ため、
# record_agency_id/record_agency_group_idはcustomer経由で解決する。Scope側もjoinsでcustomers/agenciesを
# 辿る（SalesRepresentativePolicy/ContractConditionPolicyのjoinsパターンを踏襲）。
class StorePolicy < ApplicationPolicy
  include AgencyScoped

  def record_agency_id = record.customer&.agency_id
  def record_agency_group_id = record.customer&.agency&.agency_group_id

  class Scope < ApplicationPolicy::Scope
    include AgencyScoped::ScopeMethods

    private

    def scope_for_agency
      scope.joins(:customer).where(customers: { agency_id: user.agency_id })
    end

    def scope_for_agency_group
      scope.joins(customer: :agency).where(agencies: { agency_group_id: user.agency_group_id })
    end
  end
end
