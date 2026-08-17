# frozen_string_literal: true

# 一斉通知は「代理店/顧客へ何を送るか」を決める内部運用ツールのため、Product等と同じく
# 代理店スコープの対象外（送信先の絞り込みはfilter_params側の業務ロジックであり、
# Punditの参照制御とは別レイヤー）。
class NotificationPolicy < ApplicationPolicy
  include MasterDataPolicy
end
