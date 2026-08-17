# frozen_string_literal: true

# 種別×ステータス→宛先ルーティングの割当は内部スタッフのみが編集する運用ルール
# （代理店側の自己申告で通知経路を書き換えられると業務が崩れるため、Product/CustomerStatus等
# 他のマスタ系と同じ扱いにする）。
class InquiryRecipientRoutePolicy < ApplicationPolicy
  include MasterDataPolicy
end
