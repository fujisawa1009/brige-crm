# frozen_string_literal: true

# マスタ系（Product/Plan/ProductInitialFee/ProductOption/OptionGroup/OptionValue/CustomerStatus/
# OrderStatus/ProductionCompany/SalesMaterial）共通のPolicy（04 R2タスク8）。
#
# 「Product/Plan等のマスタ系は代理店スコープ対象外＝全代理店共通閲覧でよい」（04 R2タスク8）ため
# AgencyScopedは使わず、index?/show?はログイン済みなら常に許可・Scope#resolveは常に全件を返す。
# 書き込み（create?/update?/destroy?）は内部スタッフのみ（AgencyScoped.staff_scope?を関数として再利用。
# 商材マスタ・ステータスマスタの変更が代理店側の自己申告で行えると業務ルールが崩れるため）。
#
# 実装メモ: ApplicationPolicy::Scope#resolve規約（未定義はNoMethodError）を満たすため、
# includeしたPolicyクラスの直下に `Scope`（例: ProductPolicy::Scope）を動的定義する
# （PunditはPolicyクラス名から`Policy::Scope`という固定の名前解決をするため、モジュール側の
# 定数では拾えない。const_setで各Policyクラスの名前空間に生成する）。
module MasterDataPolicy
  extend ActiveSupport::Concern

  included do
    def index?    = true
    def show?     = true
    def create?   = AgencyScoped.staff_scope?(user)
    def update?   = AgencyScoped.staff_scope?(user)
    def destroy?  = AgencyScoped.staff_scope?(user)

    const_set(:Scope, Class.new(ApplicationPolicy::Scope) do
      def resolve
        scope.all
      end
    end)
  end
end
