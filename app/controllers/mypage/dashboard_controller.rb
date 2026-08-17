# 顧客マイページ ダッシュボード（04 R4タスク5。Laravel現行 Mypage/DashboardController踏襲。
# ログイン+ダッシュボードのみの最小構成）。
class Mypage::DashboardController < Mypage::BaseController
  def index
    @customer = current_customer
    @orders = current_customer.orders.order(ordered_at: :desc).limit(20)
  end
end
