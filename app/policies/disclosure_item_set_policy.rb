# frozen_string_literal: true

# 重説項目セット（04 R5-13）はform_templatesと同じ理由（特定代理店に属さない全社共通マスタ）で
# MasterDataPolicyを踏襲する。
class DisclosureItemSetPolicy < ApplicationPolicy
  include MasterDataPolicy
end
