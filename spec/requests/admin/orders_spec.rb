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
  # CEO指示 2026-08-20 タスク7: 案件一覧の検索条件を12件へ拡充した（app/services/order_search.rb）。
  # 12条件それぞれと、参照制御・ページ送りでの保持を検証する。
  describe "一覧の検索条件（CEO指示 2026-08-20 の12条件）" do
    let!(:admin_user) { user_with_role("admin") }

    let!(:agency_x) { create(:agency, agency_group: group_a) }
    let!(:cc_x) { create(:contract_condition, agency: agency_x) }
    let!(:target_customer) do
      create(:customer, agency: agency_x, name: "案件検索ターゲット商店",
                        contractor_name_kana: "アンケンケンサク", representative_name: "案件太郎",
                        email: "order-target@example.com", phone: "0311112222",
                        status: CustomerStatus::CODE_APPLIED)
    end
    let!(:other_customer) do
      create(:customer, agency: agency_x, name: "案件対象外オフィス",
                        email: "order-miss@example.com", phone: "0399998888",
                        status: "contracted")
    end

    let!(:target) do
      create(:order, agency: agency_x, customer: target_customer, contract_condition: cc_x,
                     order_number: "ORD-TARGET-001", member_id: "B236690368",
                     ordered_at: Date.new(2026, 5, 10), contract_start_date: Date.new(2026, 5, 20),
                     cancelled_at: Date.new(2026, 5, 25), terminated_at: Date.new(2026, 5, 28),
                     payment_collected_at: Date.new(2026, 5, 30),
                     inspection_call_completed_at: Date.new(2026, 6, 1))
    end
    let!(:other) do
      create(:order, agency: agency_x, customer: other_customer, contract_condition: cc_x,
                     order_number: "ORD-OTHER-999", member_id: "B999999999",
                     ordered_at: Date.new(2026, 7, 10), contract_start_date: Date.new(2026, 7, 20),
                     cancelled_at: Date.new(2026, 7, 25), terminated_at: Date.new(2026, 7, 28),
                     payment_collected_at: Date.new(2026, 7, 30),
                     inspection_call_completed_at: nil)
    end

    before { sign_in_with_otp!(admin_user) }

    # 検索結果の判定は一覧に出る案件番号で行う（target が残り other が消えることを見る）。
    def expect_only_target(params)
      get admin_orders_path, params: params
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(target.order_number)
      expect(response.body).not_to include(other.order_number)
    end

    it "1. フリーワード: 案件番号で絞り込める" do
      expect_only_target(q: "ORD-TARGET")
    end

    it "1. フリーワード: 会員管理ID・顧客側の情報（顧客名・カナ・代表者名・メール・電話）も対象" do
      expect_only_target(q: "B236690368")
      expect_only_target(q: "案件検索ターゲット")
      expect_only_target(q: "アンケンケンサク")
      expect_only_target(q: "案件太郎")
      expect_only_target(q: "order-target@example.com")
      expect_only_target(q: "0311112222")
    end

    it "1. フリーワード: LIKEのメタ文字はエスケープされ、ワイルドカードとして解釈されない" do
      get admin_orders_path, params: { q: "%" }
      expect(response.body).not_to include(target.order_number)
      expect(response.body).not_to include(other.order_number)
    end

    it "2. 顧客番号: 部分一致で絞り込める" do
      expect_only_target(customer_number: target_customer.customer_number)
      expect_only_target(customer_number: target_customer.customer_number.last(4))
    end

    it "3. 案件番号: 部分一致で絞り込める" do
      expect_only_target(order_number: "ORD-TARGET-001")
      expect_only_target(order_number: "TARGET")
    end

    it "4. 会員管理ID: 部分一致で絞り込める" do
      expect_only_target(member_id: "B236690368")
      expect_only_target(member_id: "2366")
    end

    it "5. 顧客ステータス: プルダウンの値で絞り込める（案件自身のステータスとは別物）" do
      expect_only_target(customer_status: CustomerStatus::CODE_APPLIED)
    end

    it "5. 顧客ステータス: 検索フォームに「顧客ステータス」のプルダウンがある" do
      get admin_orders_path

      expect(response.body).to include("顧客ステータス")
      expect(response.body).to include(%(name="customer_status"))
    end

    it "6. 受注日: from〜to の期間指定で絞り込める" do
      expect_only_target(ordered_from: "2026-05-01", ordered_to: "2026-05-31")
    end

    it "7. 契約開始日: from〜to の期間指定で絞り込める" do
      expect_only_target(contract_start_from: "2026-05-01", contract_start_to: "2026-05-31")
    end

    it "8. キャンセル日: from〜to の期間指定で絞り込める" do
      expect_only_target(cancelled_from: "2026-05-01", cancelled_to: "2026-05-31")
    end

    it "9. 解約日: from〜to の期間指定で絞り込める" do
      expect_only_target(terminated_from: "2026-05-01", terminated_to: "2026-05-31")
    end

    it "10. 決済回収日: from〜to の期間指定で絞り込める" do
      expect_only_target(payment_collected_from: "2026-05-01", payment_collected_to: "2026-05-31")
    end

    it "11. 検収確認コール完了日: from〜to の期間指定で絞り込める" do
      expect_only_target(inspection_call_from: "2026-06-01", inspection_call_to: "2026-06-30")
    end

    it "6〜11. 日付は from のみ／to のみでも動く" do
      expect_only_target(ordered_to: "2026-06-30")

      get admin_orders_path, params: { ordered_from: "2026-07-01" }
      expect(response.body).to include(other.order_number)
      expect(response.body).not_to include(target.order_number)
    end

    it "6〜11. 日付は date 型なので to に指定した当日そのものを含む" do
      expect_only_target(ordered_from: "2026-05-10", ordered_to: "2026-05-10")
    end

    it "6〜11. 不正な日付文字列は条件なしとして扱う（500にしない）" do
      get admin_orders_path, params: { ordered_from: "not-a-date" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(target.order_number, other.order_number)
    end

    it "12. 検収確認コール完了日の入力があるものすべて: チェックでNOT NULLの案件だけになる" do
      expect_only_target(inspection_call_present: "1")
    end

    it "12. チェックを外すと（未送信）入力の無い案件も表示される" do
      get admin_orders_path

      expect(response.body).to include(target.order_number, other.order_number)
    end

    it "12. 期間指定（項目11）と同時指定した場合はANDで重なる" do
      expect_only_target(inspection_call_present: "1",
                         inspection_call_from: "2026-06-01", inspection_call_to: "2026-06-30")

      # 期間から外れれば、チェックが入っていても0件になる。
      get admin_orders_path, params: { inspection_call_present: "1",
                                       inspection_call_from: "2026-09-01" }
      expect(response.body).not_to include(target.order_number)
      expect(response.body).not_to include(other.order_number)
    end

    it "複数条件はAND結合される" do
      get admin_orders_path, params: { q: "ORD-TARGET", member_id: "B999999999" }

      expect(response.body).not_to include(target.order_number)
      expect(response.body).not_to include(other.order_number)
    end

    it "検索フォームは12条件を常時表示する（折りたたみを使わない）" do
      get admin_orders_path

      expect(response.body).not_to include("<details")
      %w[
        q order_number customer_number member_id customer_status inspection_call_present
        ordered_from ordered_to contract_start_from contract_start_to
        cancelled_from cancelled_to terminated_from terminated_to
        payment_collected_from payment_collected_to inspection_call_from inspection_call_to
      ].each do |field|
        expect(response.body).to include(%(name="#{field}")), "検索条件 #{field} の入力欄が無い"
      end
    end

    it "検索条件がページ送りのリンクに引き継がれる" do
      create_list(:order, 31, agency: agency_x, customer: target_customer, contract_condition: cc_x,
                              member_id: "B236690368")

      get admin_orders_path, params: { member_id: "B236690368" }

      expect(response.body).to include("member_id=B236690368")
      expect(response.body).to match(/page=2[^0-9]/)
    end
  end

  # CEO指示 2026-08-20 タスク7: 既定の並び順を order_number 降順から「受注日の新しい順」へ変更した
  # （顧客一覧の「お申込日の新しい順」と揃える。受注日=旧項目33は customers.applied_at と同じ転記元）。
  describe "案件一覧の既定の並び順（受注日の新しい順）" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_o) { create(:agency, agency_group: group_a) }
    let!(:cc_o) { create(:contract_condition, agency: agency_o) }
    let!(:customer_o) { create(:customer, agency: agency_o) }

    # 案件番号の降順と受注日の降順がわざと逆になるように作る（旧順序のままなら検知できる）。
    let!(:newest) do
      create(:order, agency: agency_o, customer: customer_o, contract_condition: cc_o,
                     order_number: "SORT-001", ordered_at: Date.new(2026, 8, 1))
    end
    let!(:middle) do
      create(:order, agency: agency_o, customer: customer_o, contract_condition: cc_o,
                     order_number: "SORT-002", ordered_at: Date.new(2026, 4, 10))
    end
    let!(:oldest) do
      create(:order, agency: agency_o, customer: customer_o, contract_condition: cc_o,
                     order_number: "SORT-003", ordered_at: Date.new(2026, 1, 5))
    end
    let!(:undated) do
      create(:order, agency: agency_o, customer: customer_o, contract_condition: cc_o,
                     order_number: "SORT-004", ordered_at: nil)
    end

    before { sign_in_with_otp!(admin_user) }

    it "受注日の新しい順に並び、受注日が未入力の案件は末尾（NULLS LAST）" do
      get admin_orders_path, params: { q: "SORT-" }

      positions = [ newest, middle, oldest, undated ].map { |o| response.body.index(o.order_number) }
      expect(positions).to eq(positions.compact.sort)
    end

    it "受注日が同値でも第2キー（案件番号の降順）で安定して並ぶ" do
      same_day = Date.new(2026, 6, 1)
      create(:order, agency: agency_o, customer: customer_o, contract_condition: cc_o,
                     order_number: "SAME-001", ordered_at: same_day)
      create(:order, agency: agency_o, customer: customer_o, contract_condition: cc_o,
                     order_number: "SAME-002", ordered_at: same_day)

      get admin_orders_path, params: { q: "SAME-" }

      positions = [ "SAME-002", "SAME-001" ].map { |n| response.body.index(n) }
      expect(positions).to eq(positions.compact.sort)
    end
  end

  # 絞り込みパラメータを参照制御の抜け道にしない（顧客一覧と同じ方針）。
  describe "案件一覧の検索条件はpolicy_scopeを迂回しない" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

    before { sign_in_with_otp!(agency_user) }

    it "他代理店の案件の会員管理IDを直接指定しても、その案件は見えない" do
      order_b.update!(member_id: "B000000001")

      get admin_orders_path, params: { member_id: "B000000001" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(order_b.order_number)
    end

    it "他代理店の顧客番号を直接指定しても、その案件は見えない" do
      get admin_orders_path, params: { customer_number: customer_b.customer_number }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(order_b.order_number)
    end
  end

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
