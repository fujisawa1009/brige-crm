# frozen_string_literal: true

# フォームビルダー（04 R3タスク6）。FormTemplateは特定代理店に属するデータではない
# （商材ごとの申込フォーム定義という全社共通のマスタ）ため、AgencyScopedではなく
# MasterDataPolicy（index?/show?は誰でも可・書き込みはstaffのみ）を踏襲する。
# 実際に代理店/代理店グループロールへこの画面を触らせるかどうかはRoleSeeder側の権限付与で
# 制御する（04 R3ではadmin/form_templatesを実務運用者専有にしており、Pundit層はその防御の内側）。
class FormTemplatePolicy < ApplicationPolicy
  include MasterDataPolicy
end
