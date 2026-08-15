# frozen_string_literal: true

# Punditはレイヤー2認可（レコード可否・参照スコープ）を担う（04 R0-6・03§3）。
# レイヤー1のSystemPermissionChecker（操作可否＝このルートを叩けるか）とAND併用する。
#
# 規約（03§6）: 個別ポリシーは Scope#resolve を必ず定義すること。ApplicationPolicy::Scope#resolve は
# 未定義のまま NoMethodError を投げるフェイルクローズが既定になっている（このメソッドを
# オーバーライドし忘れたポリシーは "resolve未定義" として即座に検出できる）。
# R1で導入する「代理店=自代理店のみ・グループ=配下のみ」のスコープ実装がこの規約の最初の適用例になる。
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
