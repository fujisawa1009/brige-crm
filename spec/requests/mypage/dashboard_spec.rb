require "rails_helper"

# 04 R4タスク5・完了条件: 顧客マイページで他顧客のデータ（Order等）へIDOR的に到達できないこと。
# ダッシュボードは current_customer.orders のみを表示する最小構成のため、ログイン顧客のスコープに
# 閉じていること・未ログインは弾かれることを検証する。
RSpec.describe "Mypage::Dashboard", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                     system_authorization: true do
  let!(:agency) { create(:agency) }
  let!(:customer_a) { create(:customer, agency: agency) }
  let!(:customer_b) { create(:customer, agency: agency) }
  let!(:order_a) { create(:order, agency: agency, customer: customer_a) }
  let!(:order_b) { create(:order, agency: agency, customer: customer_b) }

  it "未ログインではログイン画面へリダイレクトされる" do
    get mypage_dashboard_path
    expect(response).to redirect_to(new_customer_session_path)
  end

  context "顧客Aとしてログイン中" do
    before { sign_in(customer_a, scope: :customer) }

    it "自分の案件のみ表示され、他顧客の案件は見えない" do
      get mypage_dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(order_a.order_number)
      expect(response.body).not_to include(order_b.order_number)
    end
  end
end
