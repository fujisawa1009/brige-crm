# frozen_string_literal: true

# 04 R1・Column.md §1。代理店担当者はAgencyGroupに直接は属さないためrecord_agency_idは常にnil
# （=agency_scope?なユーザーは常にaccessible?=false。所属代理店経由の間接アクセスは許可しない）。
# 組織全体設定（bridge_plan_display_type等）の書き換えは自グループでも自己編集させたくないため、
# update?/destroy? も staff_scope? のみに上書きする（AgencyScoped既定のaccessible?は使わない）。
class AgencyGroupPolicy < ApplicationPolicy
  include AgencyScoped

  def update? = staff_scope?
  def destroy? = staff_scope?

  def record_agency_id = nil
  def record_agency_group_id = record.id

  class Scope < ApplicationPolicy::Scope
    include AgencyScoped::ScopeMethods

    private

    def scope_for_agency
      scope.none
    end

    def scope_for_agency_group
      scope.where(id: user.agency_group_id)
    end
  end
end
