# frozen_string_literal: true

# マスタ系（04 R2タスク8 MasterDataPolicy）と同じ扱い: 全代理店共通で参照可・書き込みは内部スタッフのみ。
class InquiryStatusPolicy < ApplicationPolicy
  include MasterDataPolicy
end
