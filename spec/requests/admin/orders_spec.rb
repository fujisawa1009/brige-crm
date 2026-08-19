require "rails_helper"

# 04 R2完了条件: 「代理店ユーザで他代理店のCustomer/Order一覧・詳細・更新に到達できないことを
# request specで確認」。OrderPolicy（app/policies/order_policy.rb）のAgencyScope適用を検証する
# （Column.md §10備考: agency_idは案件一覧のアクセス制御に使用）。
RSpec.describe "Admin::Orders", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                 system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a1) { create(:agency, agency_group: group_a) }
  let!(:agency_a2) { create(:agency, agency_group: group_a) }
  let!(:agency_b)  { create(:agency, agency_group: group_b) }
  let!(:cc_a1) { create(:contract_condition, agency: agency_a1) }
  let!(:cc_a2) { create(:contract_condition, agency: agency_a2) }
  let!(:cc_b)  { create(:contract_condition, agency: agency_b) }
  let!(:customer_a1) { create(:customer, agency: agency_a1) }
  let!(:customer_a2) { create(:customer, agency: agency_a2) }
  let!(:customer_b)  { create(:customer, agency: agency_b) }
  let!(:order_a1) { create(:order, agency: agency_a1, customer: customer_a1, contract_condition: cc_a1) }
  let!(:order_a2) { create(:order, agency: agency_a2, customer: customer_a2, contract_condition: cc_a2) }
  let!(:order_b)  { create(:order, agency: agency_b, customer: customer_b, contract_condition: cc_b) }

  describe "admin(super_admin)は全案件にCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全代理店の案件が表示される" do
      get admin_orders_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(order_a1.order_number, order_a2.order_number, order_b.order_number)
    end

    it "他代理店の案件も詳細参照できる" do
      get admin_order_path(order_b)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "代理店ユーザーは自代理店の案件のみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店の案件のみ表示される" do
      get admin_orders_path
      expect(response.body).to include(order_a1.order_number)
      expect(response.body).not_to include(order_a2.order_number)
      expect(response.body).not_to include(order_b.order_number)
    end

    it "自代理店の案件は詳細参照できる" do
      get admin_order_path(order_a1)
      expect(response).to have_http_status(:ok)
    end

    it "同一グループ内でも他代理店の案件詳細は403" do
      get admin_order_path(order_a2)
      expect(response).to have_http_status(:forbidden)
    end

    it "他代理店の案件詳細は403" do
      get admin_order_path(order_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店の案件は更新できる" do
      patch admin_order_path(order_a1), params: { order: { remarks: "自己編集後" } }
      expect(response).to redirect_to(admin_order_path(order_a1))
      expect(order_a1.reload.remarks).to eq("自己編集後")
    end

    it "他代理店の案件更新は403で内容も変わらない" do
      patch admin_order_path(order_b), params: { order: { remarks: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(order_b.reload.remarks).not_to eq("改ざん")
    end

    it "他代理店の案件削除は403" do
      delete admin_order_path(order_b)
      expect(response).to have_http_status(:forbidden)
      expect(Order.exists?(order_b.id)).to eq(true)
    end

    it "agency_idパラメータを送っても無視される（他代理店への付け替え防止）" do
      patch admin_order_path(order_a1), params: { order: { remarks: "x", agency_id: agency_b.id } }
      expect(order_a1.reload.agency_id).to eq(agency_a1.id)
    end

    it "customer_id/store_idパラメータを他代理店のレコードへ書き換えても無視される（04 R2追補バグ修正）" do
      store_b = create(:store, customer: customer_b)

      patch admin_order_path(order_a1), params: {
        order: { remarks: "x", customer_id: customer_b.id, store_id: store_b.id }
      }

      order_a1.reload
      expect(order_a1.customer_id).to eq(customer_a1.id)
      expect(order_a1.store_id).not_to eq(store_b.id)
    end

    it "編集フォームの選択肢に他代理店の顧客・契約条件・営業担当者が混入しない（2026-08-19 認可監査で発見・是正）" do
      store_b = create(:store, customer: customer_b)
      sales_rep_a1 = create(:sales_representative, agency: agency_a1)
      sales_rep_b = create(:sales_representative, agency: agency_b)

      get edit_admin_order_path(order_a1)

      expect(response.body).to include(customer_a1.name)
      expect(response.body).not_to include(customer_b.name)
      expect(response.body).to include(cc_a1.name)
      expect(response.body).not_to include(cc_b.name)
      expect(response.body).not_to include(store_b.store_name)
      expect(response.body).to include(sales_rep_a1.name)
      expect(response.body).not_to include(sales_rep_b.name)
    end
  end

  describe "代理店グループユーザーは配下代理店の案件のみ" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には配下代理店の案件のみ表示される" do
      get admin_orders_path
      expect(response.body).to include(order_a1.order_number, order_a2.order_number)
      expect(response.body).not_to include(order_b.order_number)
    end

    it "配下代理店の案件詳細は参照できる" do
      get admin_order_path(order_a2)
      expect(response).to have_http_status(:ok)
    end

    it "配下外の代理店の案件詳細は403" do
      get admin_order_path(order_b)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
