# frozen_string_literal: true

# 04 R1。代理店/代理店グループが自分の配下アカウント（サブユーザー）を管理する運用を想定し、
# AgencyScoped既定どおりupdate?/destroy?もaccessible?とする。agency_id/agency_group_id の付け替え
# （他代理店への移設・グループへの昇格）は Admin::UsersController 側（strip_ownership_params!）で
# staff以外から防御する。パスワード自体はこの管理画面CRUDでは扱わない（既存のusers/registrations
# コントローラのセルフサービスに委ねる。create?時のみ初期パスワード発行のため例外的に扱う）。
class UserPolicy < ApplicationPolicy
  include AgencyScoped

  def record_agency_id = record.agency_id
  def record_agency_group_id = record.agency_group_id || record.agency&.agency_group_id

  class Scope < ApplicationPolicy::Scope
    include AgencyScoped::ScopeMethods

    private

    def scope_for_agency
      scope.where(agency_id: user.agency_id)
    end

    def scope_for_agency_group
      scope.where(agency_group_id: user.agency_group_id)
           .or(scope.where(agency_id: Agency.where(agency_group_id: user.agency_group_id)))
    end
  end
end
