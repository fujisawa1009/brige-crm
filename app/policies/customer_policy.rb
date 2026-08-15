# frozen_string_literal: true

# 04 R2完了条件: 「R1で確立したPundit policy_scope（代理店=自代理店のみ・グループ=配下のみ）を
# Customer/Store/Orderにも適用」。Customerはagency_idを直接持つため、AgencyPolicy等と同じ実装で足りる。
# update?/destroy?はAgencyScoped既定のaccessible?のまま（自代理店・配下代理店の顧客編集を許可）。
# create?も既定のstaff_scope?のまま（代理店側からの新規顧客登録はR3申込フォーム経由が本流のため、
# 管理画面からの直接作成は内部スタッフの運用に限定する。04 R1の同方針をCustomer/Orderにも踏襲）。
class CustomerPolicy < ApplicationPolicy
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
