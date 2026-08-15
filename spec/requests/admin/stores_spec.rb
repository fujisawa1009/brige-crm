require "rails_helper"

# 04 R2完了条件: StorePolicy（app/policies/store_policy.rb）はcustomer経由でagencyスコープを解決する
# （Storeはagency_idを直接持たないため）。CustomerPolicy/OrderPolicyと同じ絞り込みが効くことを確認する。
RSpec.describe "Admin::Stores", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                 system_authorization: true do
  let!(:agency_a) { create(:agency) }
  let!(:agency_b) { create(:agency) }
  let!(:customer_a) { create(:customer, agency: agency_a) }
  let!(:customer_b) { create(:customer, agency: agency_b) }
  let!(:store_a) { create(:store, customer: customer_a, store_name: "店舗A") }
  let!(:store_b) { create(:store, customer: customer_b, store_name: "店舗B") }

  describe "代理店ユーザーは自代理店の顧客配下の店舗のみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a) }

    before { sign_in_with_otp!(agency_user) }

    it "自代理店の顧客の店舗一覧は参照できる" do
      get admin_customer_stores_path(customer_a)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(store_a.store_name)
    end

    it "他代理店の顧客IDを直接指定した店舗一覧は403（set_customer側のPunditチェック）" do
      get admin_customer_stores_path(customer_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "他代理店の店舗詳細に自代理店の顧客経由の不正なURLでも到達できない" do
      get admin_customer_store_path(customer_b, store_b)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
