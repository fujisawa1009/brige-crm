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

  # R6-6: 一覧の「完了済みを含む」検索。CompletionStatusFilter(status_klass: OrderStatus)が
  # コントローラーの#indexへ正しく結線されていることを確認する（単体ロジック自体は
  # spec/services/completion_status_filter_spec.rbで検証済み）。
  describe "R6-6: 完了済みを含む検索" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:completed_order) do
      create(:order, agency: agency_a1, customer: customer_a1, contract_condition: cc_a1, status: "16:完了")
    end

    before { sign_in_with_otp!(admin_user) }

    it "既定（include_completed未指定）では完了系ステータスの案件が一覧から除外される" do
      get admin_orders_path
      expect(response.body).not_to include(completed_order.order_number)
      expect(response.body).to include(order_a1.order_number)
    end

    it "include_completed=1を指定すると完了系ステータスの案件も表示される" do
      get admin_orders_path, params: { include_completed: "1" }
      expect(response.body).to include(completed_order.order_number)
    end

    it "既存のstatus絞り込みと併用でき、完了ステータスを明示指定すればそのステータスの案件が見える" do
      get admin_orders_path, params: { status: "16:完了" }
      expect(response.body).to include(completed_order.order_number)
      expect(response.body).not_to include(order_a1.order_number)
    end
  end

  # R6-7: ガントチャート（受注日→契約開始日→納品日等の経過管理）。JSON API（Admin::OrdersController#gantt
  # format: :json）がpolicy_scopeを迂回して他代理店のOrderを露出しないことを検証する
  # （2026-08-19の認可監査で発見・是正した類似の脆弱性の再発防止が目的）。
  describe "R6-7: ガントチャート" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:dated_order_a1) do
      create(:order, agency: agency_a1, customer: customer_a1, contract_condition: cc_a1,
                      ordered_at: Date.new(2026, 1, 10), work_completed_at: Date.new(2026, 2, 20))
    end
    let!(:dated_order_b) do
      create(:order, agency: agency_b, customer: customer_b, contract_condition: cc_b,
                      ordered_at: Date.new(2026, 1, 5), work_completed_at: Date.new(2026, 1, 25))
    end

    context "admin(super_admin)" do
      before { sign_in_with_otp!(admin_user) }

      it "html表示できる" do
        get gantt_admin_orders_path
        expect(response).to have_http_status(:ok)
      end

      it "JSON APIは全代理店の日付ありOrderをタスクとして返す" do
        get gantt_admin_orders_path(format: :json)
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body.map { |task| task["id"] }
        expect(ids).to include(dated_order_a1.id, dated_order_b.id)
      end

      it "受注日・契約開始日・納品日・解約日が全てnilの案件はガントに出さない" do
        get gantt_admin_orders_path(format: :json)
        ids = response.parsed_body.map { |task| task["id"] }
        # order_a1（外側のletで定義。日付フィールド未設定）は対象外になる
        expect(ids).not_to include(order_a1.id)
      end

      it "開始・終了日を欠損補完してISO8601形式で返す（終了=納品完了日を優先）" do
        get gantt_admin_orders_path(format: :json)
        task = response.parsed_body.find { |t| t["id"] == dated_order_a1.id }

        expect(task["start"]).to eq("2026-01-10")
        expect(task["end"]).to eq("2026-02-20")
      end
    end

    context "代理店ユーザー" do
      let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

      before { sign_in_with_otp!(agency_user) }

      it "html表示できる" do
        get gantt_admin_orders_path
        expect(response).to have_http_status(:ok)
      end

      it "JSON APIは自代理店のOrderのみ返し、他代理店のOrderは漏れない" do
        get gantt_admin_orders_path(format: :json)
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body.map { |task| task["id"] }
        expect(ids).to include(dated_order_a1.id)
        expect(ids).not_to include(dated_order_b.id)
      end
    end

    describe "完了済みを含む検索（R6-6と同じCompletionStatusFilterを再利用）" do
      let!(:completed_dated_order) do
        create(:order, agency: agency_a1, customer: customer_a1, contract_condition: cc_a1, status: "16:完了",
                        ordered_at: Date.new(2026, 1, 1), work_completed_at: Date.new(2026, 1, 15))
      end

      before { sign_in_with_otp!(admin_user) }

      it "既定（include_completed未指定）では完了系ステータスの案件を除外する" do
        get gantt_admin_orders_path(format: :json)
        ids = response.parsed_body.map { |task| task["id"] }
        expect(ids).not_to include(completed_dated_order.id)
      end

      it "include_completed=1を指定すると完了系ステータスの案件も表示される" do
        get gantt_admin_orders_path(format: :json), params: { include_completed: "1" }
        ids = response.parsed_body.map { |task| task["id"] }
        expect(ids).to include(completed_dated_order.id)
      end
    end
  end
end
