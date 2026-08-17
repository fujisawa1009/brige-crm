# frozen_string_literal: true

# 04 R4タスク1。CustomerPolicy/OrderPolicyと同じAgencyScoped適用（案件経由の間接スコープ。
# record_agency_idは常にinquiry.order.agency_idを参照する）。
# is_visible_to_agent=falseの問い合わせは代理店/代理店グループ側からは不可視にする
# （Laravel現行のis_visible_to_agentフラグ踏襲。社内限定のやり取りを隠す用途）。
# createはstaff_scope?限定（問い合わせの起票は内部運用フロー。R4は「Inquiry作成→宛先解決→
# InquiryMessage往復」がスコープであり、代理店側からの起票UIはR4の対象外）。
class InquiryPolicy < ApplicationPolicy
  include AgencyScoped

  def show?
    return false if !staff_scope? && !record.is_visible_to_agent?

    accessible?
  end

  def record_agency_id = record.order&.agency_id
  def record_agency_group_id = record.order&.agency&.agency_group_id

  class Scope < ApplicationPolicy::Scope
    include AgencyScoped::ScopeMethods

    def resolve
      base = super
      AgencyScoped.staff_scope?(user) ? base : base.visible_to_agent
    end

    private

    def scope_for_agency
      scope.joins(:order).where(orders: { agency_id: user.agency_id })
    end

    def scope_for_agency_group
      scope.joins(order: :agency).where(agencies: { agency_group_id: user.agency_group_id })
    end
  end
end
