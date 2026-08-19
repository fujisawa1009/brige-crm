# frozen_string_literal: true

# R6-8 ファイル管理基盤。OrderPolicy/InquiryPolicyと同じAgencyScoped適用（案件経由の間接スコープ。
# record_agency_idは常にorder_attachment.order.agency_idを参照する）。
#
# show?（=ダウンロード時のauthorize対象。Admin::OrderAttachmentsController#download参照）は
# AgencyScoped既定のaccessible?のまま: is_visible_to_customerは「顧客（マイページ）へ見せるか」の
# フラグであり、代理店/実務運用者は内部関係者として同一Orderの添付ファイルを可視/不可視問わず
# 参照できてよい（InquiryPolicyがis_visible_to_agentで代理店を制限するのとは異なる設計。
# 顧客側のゲートはMypage::OrderAttachmentsController側で別途is_visible_to_customerを見る）。
#
# destroy?はAgencyScoped既定のaccessible?を上書きしstaff_scope?限定にする: 添付ファイルは将来
# R5-11の契約書PDF等、代理店側の自己判断で失わせてはいけない文書を保持しうるため、
# AgencyGroup/ContractConditionと同じ「書き込み・削除は内部運用の管轄」という04 R1方針をここでも
# 適用する（create?はAgencyScoped既定のstaff_scope?のままで変更不要）。
class OrderAttachmentPolicy < ApplicationPolicy
  include AgencyScoped

  def destroy? = staff_scope?

  def record_agency_id = record.order&.agency_id
  def record_agency_group_id = record.order&.agency&.agency_group_id

  class Scope < ApplicationPolicy::Scope
    include AgencyScoped::ScopeMethods

    private

    def scope_for_agency
      scope.joins(:order).where(orders: { agency_id: user.agency_id })
    end

    def scope_for_agency_group
      scope.joins(order: :agency).where(agencies: { agency_group_id: user.agency_group_id })
    end
  end
end
