# frozen_string_literal: true

# 04 R1・Column.md §2。destroy? は組織構造の削除操作のためstaff_scope?のみに上書きする
# （AgencyScoped既定のaccessible?のままだと自代理店ユーザーが自分自身のAgencyを削除できてしまう）。
# update? はAgencyScoped既定のaccessible?のまま（連絡先メール等の自己編集は許可する）。ただし
# agency_group_id を書き換えられると自代理店を別グループへ付け替える権限昇格経路になるため、
# その防御は Admin::AgenciesController 側（strip_ownership_params!）で行う。
class AgencyPolicy < ApplicationPolicy
  include AgencyScoped

  def destroy? = staff_scope?

  def record_agency_id = record.id
  def record_agency_group_id = record.agency_group_id

  class Scope < ApplicationPolicy::Scope
    include AgencyScoped::ScopeMethods

    private

    def scope_for_agency
      scope.where(id: user.agency_id)
    end

    def scope_for_agency_group
      scope.where(agency_group_id: user.agency_group_id)
    end
  end
end
