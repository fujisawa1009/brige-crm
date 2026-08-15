# frozen_string_literal: true

# CSVエクスポート成果物へのアクセス制御（04 R2タスク7）。自分がリクエストしたエクスポートのみ
# 参照・ダウンロード可能（staffは全件参照可。運用サポート用）。他ユーザーのエクスポートを覗ければ
# CsvExportJobがpolicy_scopeで絞った意味が無くなるため、ここでも二重に絞る。
class CsvExportPolicy < ApplicationPolicy
  def index? = true # 一覧はScope#resolveが自分のものだけに絞る
  def show?  = staff? || record.requested_by_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      AgencyScoped.staff_scope?(user) ? scope.all : scope.where(requested_by_id: user.id)
    end
  end

  private

  def staff?
    AgencyScoped.staff_scope?(user)
  end
end
