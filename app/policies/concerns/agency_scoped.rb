# frozen_string_literal: true

# 04 R1「代理店ユーザ=自代理店のみ閲覧・操作可、代理店グループユーザ=配下代理店のみ」を横断適用する
# ための共通Policyモジュール。「以降の全エンティティで必須」の原則（04 R1本文）に従い、R2以降の
# 新規Policyもこのモジュールをincludeし、record_agency_id / record_agency_group_id の2メソッドと
# Scope側の scope_for_agency / scope_for_agency_group の2メソッドを実装するだけで同じ参照制御を
# 持てるようにする（AgencyGroup/Agency/SalesRepresentative/ContractCondition/User が最初の適用例）。
#
# スコープ種別の判定は SystemRole の名前文字列ではなく、users.agency_id / agency_group_id という
# 「所属」そのもの（01§2-1・Column.md §2「権限・アクセス制御の方針」踏襲）で行う。admin/実務運用者は
# 両方nilのため全件アクセス（staff_scope）。代理店担当者はagency_idのみ、代理店グループ担当者は
# agency_group_idのみ設定という前提を User#agency_scope_is_exclusive バリデーションで担保している。
#
# 書き込み系の既定方針（04 R1・CTO決定。理由はREADMEおよびコミットメッセージ参照）:
#   - create? は既定で staff_scope? のみ（組織構造・契約条件・アカウント発行は内部運用の管轄とし、
#     代理店側の自己申告パラメータによる権限昇格の経路を作らない）
#   - update?/destroy? は既定で accessible?（自分のスコープ内なら自己申告データの編集を許可）
#   - ただし AgencyGroup（組織全体設定）・ContractCondition（契約条件＝手数料等の商取引条件）は
#     update?/destroy? も staff_scope? のみに個別Policy側で上書きする（自己編集させない）
module AgencyScoped
  extend ActiveSupport::Concern

  included do
    def index?
      true # 一覧そのものには誰でも到達可。絞り込みは Scope#resolve が担う
    end

    def show?
      accessible?
    end

    def create?
      staff_scope?
    end

    def update?
      accessible?
    end

    def destroy?
      accessible?
    end
  end

  def accessible?
    return true if staff_scope?
    return record_agency_id.present? && record_agency_id == user.agency_id if agency_scope?
    return record_agency_group_id.present? && record_agency_group_id == user.agency_group_id if agency_group_scope?

    false
  end

  def staff_scope?
    AgencyScoped.staff_scope?(user)
  end

  def agency_scope?
    AgencyScoped.agency_scope?(user)
  end

  def agency_group_scope?
    AgencyScoped.agency_group_scope?(user)
  end

  # 各Policyでオーバーライド必須。レコードが属する代理店/代理店グループのUUIDを返す
  # （該当しない場合はnil。例: AgencyGroupのrecord_agency_idは常にnil＝代理店担当者はアクセス不可）。
  def record_agency_id
    raise NotImplementedError, "#{self.class} must implement #record_agency_id"
  end

  def record_agency_group_id
    raise NotImplementedError, "#{self.class} must implement #record_agency_group_id"
  end

  # Policy/Scope の両方から同じ判定基準を使うためのモジュール関数。
  def self.staff_scope?(user)
    user.agency_id.blank? && user.agency_group_id.blank?
  end

  def self.agency_scope?(user)
    user.agency_id.present?
  end

  def self.agency_group_scope?(user)
    user.agency_id.blank? && user.agency_group_id.present?
  end

  # Scope（policy_scope用）側の共通実装。各Policy::Scopeで
  # `include AgencyScoped::ScopeMethods` し、scope_for_agency / scope_for_agency_group を実装する。
  module ScopeMethods
    extend ActiveSupport::Concern

    def resolve
      return scope.all if AgencyScoped.staff_scope?(user)
      return scope_for_agency if AgencyScoped.agency_scope?(user)
      return scope_for_agency_group if AgencyScoped.agency_group_scope?(user)

      scope.none
    end

    private

    def scope_for_agency
      raise NotImplementedError, "#{self.class} must implement #scope_for_agency"
    end

    def scope_for_agency_group
      raise NotImplementedError, "#{self.class} must implement #scope_for_agency_group"
    end
  end
end
