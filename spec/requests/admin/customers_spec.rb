require "rails_helper"

# 04 R2完了条件: 「代理店ユーザで他代理店のCustomer/Order一覧・詳細・更新に到達できないことを
# request specで確認」。CustomerPolicy（app/policies/customer_policy.rb）のAgencyScope適用を検証する。
RSpec.describe "Admin::Customers", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                    system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a1) { create(:agency, agency_group: group_a) }
  let!(:agency_a2) { create(:agency, agency_group: group_a) }
  let!(:agency_b)  { create(:agency, agency_group: group_b) }
  let!(:customer_a1) { create(:customer, agency: agency_a1, name: "顧客A1") }
  let!(:customer_a2) { create(:customer, agency: agency_a2, name: "顧客A2") }
  let!(:customer_b)  { create(:customer, agency: agency_b, name: "顧客B") }

  describe "admin(super_admin)は全顧客にCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全代理店の顧客が表示される" do
      get admin_customers_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer_a1.name, customer_a2.name, customer_b.name)
    end

    it "他代理店の顧客も詳細参照できる" do
      get admin_customer_path(customer_b)
      expect(response).to have_http_status(:ok)
    end

    it "更新できる" do
      patch admin_customer_path(customer_b), params: { customer: { name: "更新後" } }
      expect(customer_b.reload.name).to eq("更新後")
    end
  end

  describe "代理店ユーザーは自代理店の顧客のみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店の顧客のみ表示される" do
      get admin_customers_path
      expect(response.body).to include(customer_a1.name)
      expect(response.body).not_to include(customer_a2.name)
      expect(response.body).not_to include(customer_b.name)
    end

    it "自代理店の顧客は詳細参照できる" do
      get admin_customer_path(customer_a1)
      expect(response).to have_http_status(:ok)
    end

    it "同一グループ内でも他代理店の顧客詳細は403" do
      get admin_customer_path(customer_a2)
      expect(response).to have_http_status(:forbidden)
    end

    it "他代理店の顧客詳細は403" do
      get admin_customer_path(customer_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店の顧客は更新できる" do
      patch admin_customer_path(customer_a1), params: { customer: { name: "自己編集後" } }
      expect(response).to redirect_to(admin_customer_path(customer_a1))
      expect(customer_a1.reload.name).to eq("自己編集後")
    end

    it "他代理店の顧客更新は403で内容も変わらない" do
      patch admin_customer_path(customer_b), params: { customer: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(customer_b.reload.name).not_to eq("改ざん")
    end

    it "他代理店の顧客削除は403" do
      delete admin_customer_path(customer_b)
      expect(response).to have_http_status(:forbidden)
      expect(Customer.exists?(customer_b.id)).to eq(true)
    end

    it "agency_idパラメータを送っても無視される（他代理店への付け替え防止）" do
      patch admin_customer_path(customer_a1), params: { customer: { name: "x", agency_id: agency_b.id } }
      expect(customer_a1.reload.agency_id).to eq(agency_a1.id)
    end

    it "編集フォームの選択肢に他代理店の営業担当者が混入しない（2026-08-19 認可監査で発見・是正）" do
      sales_rep_a1 = create(:sales_representative, agency: agency_a1)
      sales_rep_b = create(:sales_representative, agency: agency_b)

      get edit_admin_customer_path(customer_a1)

      expect(response.body).to include(sales_rep_a1.name)
      expect(response.body).not_to include(sales_rep_b.name)
    end
  end

  describe "代理店グループユーザーは配下代理店の顧客のみ" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には配下代理店の顧客のみ表示される" do
      get admin_customers_path
      expect(response.body).to include(customer_a1.name, customer_a2.name)
      expect(response.body).not_to include(customer_b.name)
    end

    it "配下代理店の顧客詳細は参照できる" do
      get admin_customer_path(customer_a2)
      expect(response).to have_http_status(:ok)
    end

    it "配下外の代理店の顧客詳細は403" do
      get admin_customer_path(customer_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "配下外の代理店の顧客更新は403" do
      patch admin_customer_path(customer_b), params: { customer: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # CEO指示 2026-08-20: 顧客一覧の検索条件を旧ジャスミン相当の9条件へ拡充した
  # （app/services/customer_search.rb）。9条件それぞれと、参照制御・ページ送りでの保持を検証する。
  describe "一覧の検索条件（CEO指示 2026-08-20 の9条件）" do
    let!(:admin_user) { user_with_role("admin") }

    let!(:group_x) { create(:agency_group, group_code: "GRPX", name: "エックス商事グループ") }
    let!(:group_y) { create(:agency_group, group_code: "GRPY", name: "ワイ物産グループ") }
    let!(:agency_x) { create(:agency, agency_group: group_x, agency_code: "AGX", name: "エックス東京支店") }
    let!(:agency_y) { create(:agency, agency_group: group_y, agency_code: "AGY", name: "ワイ大阪支店") }

    let!(:target) do
      create(:customer, agency: agency_x, name: "検索対象ターゲット商店",
                        contractor_name_kana: "ケンサクタイショウ", representative_name: "検索太郎",
                        email: "target-hit@example.com", phone: "0312345678",
                        status: CustomerStatus::CODE_APPLIED, applied_at: Date.new(2026, 5, 10))
    end
    # other は退会済みにしない。一覧は既定で退会済みを除外する（CEO指示 2026-08-20）ため、
    # 退会済みにすると各条件が効いたのか既定除外で消えたのかを区別できなくなる。
    # 退会済みの挙動そのものは後段の専用 describe で検証する。
    let!(:other) do
      create(:customer, agency: agency_y, name: "対象外オフィス",
                        email: "miss@example.com", phone: "0699999999",
                        status: "contracted", applied_at: Date.new(2026, 7, 20))
    end

    before { sign_in_with_otp!(admin_user) }

    # 検索結果の判定は一覧に出る顧客名で行う（target が残り other が消えることを見る）。
    def expect_only_target(params)
      get admin_customers_path, params: params
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(target.name)
      expect(response.body).not_to include(other.name)
    end

    it "1. フリーワード: 氏名で絞り込める" do
      expect_only_target(q: "ターゲット")
    end

    it "1. フリーワード: 氏名以外（カナ・代表者名・メール・電話）も対象に含む" do
      expect_only_target(q: "ケンサクタイショウ")
      expect_only_target(q: "検索太郎")
      expect_only_target(q: "target-hit@example.com")
      expect_only_target(q: "0312345678")
    end

    it "1. フリーワード: LIKEのメタ文字はエスケープされ、ワイルドカードとして解釈されない" do
      get admin_customers_path, params: { q: "%" }
      expect(response.body).not_to include(target.name)
      expect(response.body).not_to include(other.name)
    end

    it "2. FTWEB顧客番号: 部分一致で絞り込める（旧実装踏襲）" do
      expect_only_target(customer_number: target.customer_number)
      expect_only_target(customer_number: target.customer_number.last(4))
    end

    it "3. グループ会社コード: 完全一致で絞り込める" do
      expect_only_target(group_code: "GRPX")
    end

    it "3. グループ会社コード: 部分文字列では一致しない（完全一致のため）" do
      get admin_customers_path, params: { group_code: "GRP" }
      expect(response.body).not_to include(target.name)
      expect(response.body).not_to include(other.name)
    end

    it "4. グループ会社名: 部分一致で絞り込める" do
      expect_only_target(group_name: "エックス商事")
    end

    it "5. 代理店コード: 完全一致で絞り込める" do
      expect_only_target(agency_code: "AGX")
    end

    it "6. 代理店名: 部分一致で絞り込める" do
      expect_only_target(agency_name: "東京")
    end

    it "7. 状況（ステータス）: 完全一致で絞り込める" do
      expect_only_target(status: CustomerStatus::CODE_APPLIED)
    end

    it "8. お申込日: from〜to の期間指定で絞り込める" do
      expect_only_target(applied_from: "2026-05-01", applied_to: "2026-05-31")
    end

    it "8. お申込日: from のみ／to のみでも動く" do
      get admin_customers_path, params: { applied_from: "2026-07-01" }
      expect(response.body).not_to include(target.name)
      expect(response.body).to include(other.name)

      expect_only_target(applied_to: "2026-06-30")
    end

    it "8. お申込日: 不正な日付文字列は条件なしとして扱う（500にしない）" do
      get admin_customers_path, params: { applied_from: "not-a-date" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(target.name, other.name)
    end

    it "9. 最終更新日時: from〜to の期間指定で絞り込める（当日を含む）" do
      other.update_column(:updated_at, 10.days.ago)
      today = Date.current.to_fs(:iso8601)
      expect_only_target(updated_from: today, updated_to: today)
    end

    it "9. 最終更新日時: from のみ／to のみでも動く" do
      other.update_column(:updated_at, 10.days.ago)
      expect_only_target(updated_from: 1.day.ago.to_date.to_fs(:iso8601))

      get admin_customers_path, params: { updated_to: 5.days.ago.to_date.to_fs(:iso8601) }
      expect(response.body).to include(other.name)
      expect(response.body).not_to include(target.name)
    end

    it "複数条件はAND結合される" do
      get admin_customers_path, params: { q: "ターゲット", group_code: "GRPY" }
      expect(response.body).not_to include(target.name)
      expect(response.body).not_to include(other.name)
    end

    it "検索条件がページ送りのリンクに引き継がれる（共通ページネーション）" do
      create_list(:customer, 30, agency: agency_x, name: "ページ送り検証顧客")

      get admin_customers_path, params: { agency_code: "AGX" }

      expect(response.body).to include("agency_code=AGX")
      expect(response.body).to match(/page=2[^0-9]/)
      # 共通ページネーション（app/views/shared/_pagination.html.erb）の総件数・表示範囲。
      expect(response.body).to match(/全 31 件中 1〜\d+ 件を表示/)
    end

    it "1件もヒットしない場合もページネーションが崩れない（全 0 件と表示する）" do
      get admin_customers_path, params: { q: "該当なしのはずのキーワード" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<p class="pagination-summary">全 0 件</p>))
    end
  end

  # CEO指示 2026-08-20（画面目視）: 「詳細条件」の折りたたみ（details）を廃止し、
  # 9条件すべてを最初から表示する。折りたたみが復活していないことを回帰として見る。
  describe "検索フォームは9条件を常時表示する（折りたたみ廃止）" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "details/summary（詳細条件の折りたたみ）が存在しない" do
      get admin_customers_path

      expect(response.body).not_to include("<details")
      expect(response.body).not_to include("詳細条件")
    end

    it "9条件すべての入力欄が最初から描画されている" do
      get admin_customers_path

      %w[
        q status customer_number group_code group_name agency_code agency_name
        applied_from applied_to updated_from updated_to
      ].each do |field|
        expect(response.body).to include(%(name="#{field}")), "検索条件 #{field} の入力欄が無い"
      end

      expect(response.body).to include("フリーワード", "FTWEB顧客番号", "グループ会社コード",
                                       "グループ会社名", "代理店コード", "代理店名",
                                       "ステータス", "お申込日", "最終更新日時")
    end

    # CEO指示 2026-08-20（目視確認）: 日付の期間指定は「1欄のカレンダーで開始と終了を選ぶ」形にした。
    # 案件一覧（spec/requests/admin/orders_spec.rb）と同じ共通パーシャルを使う。サーバ側
    # （CustomerSearch）のパラメータ名は from/to のままなので、絞り込み仕様は上のテスト群が担保する。
    # ここで守るのは「JS未接続でも検索できる素の date 入力が初期状態で出ていること」。
    it "日付2種がレンジピッカーに接続され、JS未接続時のフォールバック（date入力2つ）も描画される" do
      get admin_customers_path

      expect(response.body.scan('data-controller="date-range"').size).to eq(2)
      expect(response.body).to include(%(class="relative hidden" data-date-range-target="picker"))

      %w[applied_from applied_to updated_from updated_to].each do |field|
        expect(response.body[/<input[^>]*name="#{field}"[^>]*>/]).to include(%(type="date")),
                                                                     "#{field} が date 入力ではない"
      end
    end
  end

  # CEO指示 2026-08-20: 顧客一覧は既定で退会済みを除外し、「退会済みを含む」チェックを
  # 入れたときだけ表示する（旧ジャスミン Laravel 版の show_withdrawn と同じ挙動）。
  # 退会の判定は customers.status == CustomerStatus::CODE_WITHDRAWN（Customer.active スコープ）。
  describe "退会済み顧客の表示（show_withdrawn）" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_w) { create(:agency) }
    let!(:active_customer) do
      create(:customer, agency: agency_w, name: "現役ゼット商会", status: CustomerStatus::CODE_APPLIED)
    end
    let!(:withdrawn_customer) do
      create(:customer, agency: agency_w, name: "退会済みゼット商会", status: CustomerStatus::CODE_WITHDRAWN)
    end

    before { sign_in_with_otp!(admin_user) }

    it "既定（パラメータ無し）では退会済みが表示されない" do
      get admin_customers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active_customer.name)
      expect(response.body).not_to include(withdrawn_customer.name)
    end

    it "「退会済みを含む」にチェックすると退会済みも表示される" do
      get admin_customers_path, params: { show_withdrawn: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active_customer.name, withdrawn_customer.name)
    end

    it "チェックを外した状態（show_withdrawn=0）では退会済みが表示されない" do
      get admin_customers_path, params: { show_withdrawn: "0" }

      expect(response.body).to include(active_customer.name)
      expect(response.body).not_to include(withdrawn_customer.name)
    end

    it "他の検索条件と併用しても既定除外が効く" do
      get admin_customers_path, params: { q: "ゼット商会" }

      expect(response.body).to include(active_customer.name)
      expect(response.body).not_to include(withdrawn_customer.name)
    end

    # 採用した挙動: ステータスで「退会済み」を明示選択した場合は、チェックが無くても表示する。
    # そうしないと選択した瞬間に必ず0件になり、絞り込みとして意味を成さないため。
    it "ステータスで退会済みを明示選択した場合はチェック無しでも表示される" do
      get admin_customers_path, params: { status: CustomerStatus::CODE_WITHDRAWN }

      expect(response.body).to include(withdrawn_customer.name)
      expect(response.body).not_to include(active_customer.name)
    end

    it "検索フォームに「退会済みを含む」チェックボックスがあり、既定は未チェック" do
      get admin_customers_path

      expect(response.body).to include("退会済みを含む")
      expect(response.body).to include(%(name="show_withdrawn"))
      expect(response.body).not_to match(/name="show_withdrawn"[^>]*checked/)
    end

    it "チェック状態はリロード後もフォームに保持される" do
      get admin_customers_path, params: { show_withdrawn: "1" }

      expect(response.body).to match(/name="show_withdrawn"[^>]*checked|checked[^>]*name="show_withdrawn"/)
    end

    it "退会済みの件数はページネーションの総件数にも含まれない" do
      get admin_customers_path, params: { q: "ゼット商会" }
      expect(response.body).to include("全 1 件")

      get admin_customers_path, params: { q: "ゼット商会", show_withdrawn: "1" }
      expect(response.body).to include("全 2 件")
    end
  end

  # CEO決定 2026-08-20 タスク4: 一覧の既定の並び順を旧ジャスミン（Laravel版）と同じ
  # 「お申込日の新しい順」に合わせる（旧は applied_at DESC 固定。Rails版は customer_number ASC だった）。
  describe "一覧の既定の並び順（お申込日の新しい順）" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_s) { create(:agency) }

    # 顧客番号の昇順と申込日の降順がわざと逆になるように作る（旧順序のままなら検知できる）。
    let!(:oldest) { create(:customer, agency: agency_s, name: "並び順_古い", applied_at: Date.new(2026, 1, 5)) }
    let!(:newest) { create(:customer, agency: agency_s, name: "並び順_新しい", applied_at: Date.new(2026, 8, 1)) }
    let!(:middle) { create(:customer, agency: agency_s, name: "並び順_中間", applied_at: Date.new(2026, 4, 10)) }
    let!(:undated) { create(:customer, agency: agency_s, name: "並び順_未入力", applied_at: nil) }

    before { sign_in_with_otp!(admin_user) }

    def displayed_order(names)
      names.map { |name| response.body.index(name) }
    end

    it "お申込日の新しい順に並ぶ" do
      get admin_customers_path, params: { q: "並び順_" }

      positions = displayed_order([ newest.name, middle.name, oldest.name ])
      expect(positions).to eq(positions.compact.sort)
    end

    it "お申込日が未入力の顧客は末尾に並ぶ（NULLS LAST）" do
      get admin_customers_path, params: { q: "並び順_" }

      positions = displayed_order([ newest.name, middle.name, oldest.name, undated.name ])
      expect(positions).to eq(positions.compact.sort)
    end

    it "お申込日が同値でも第2キー（顧客番号）で安定して並ぶ" do
      same_day = Date.new(2026, 6, 1)
      a = create(:customer, agency: agency_s, name: "同日_甲", applied_at: same_day)
      b = create(:customer, agency: agency_s, name: "同日_乙", applied_at: same_day)
      expected = [ a, b ].sort_by(&:customer_number).map(&:name)

      get admin_customers_path, params: { q: "同日_" }

      positions = displayed_order(expected)
      expect(positions).to eq(positions.compact.sort)
    end
  end

  # CEO決定 2026-08-20 タスク5: 1ページの表示件数を旧と同じ30件に統一する
  # （pagy 既定の20件から変更。config/initializers/pagy.rb で一元管理）。
  describe "1ページの表示件数" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_p) { create(:agency) }

    before { sign_in_with_otp!(admin_user) }

    it "1ページ30件で区切られる" do
      create_list(:customer, 31, agency: agency_p, name: "件数検証顧客")

      get admin_customers_path, params: { q: "件数検証顧客" }

      expect(response.body).to include("全 31 件中 1〜30 件を表示")
      expect(response.body).to match(/page=2[^0-9]/)
    end

    it "pagyの既定値が30に設定されている" do
      expect(Pagy::DEFAULT[:items]).to eq(30)
    end
  end

  # 検索条件は policy_scope の内側でしか効かない（絞り込みパラメータを参照制御の抜け道にしない）。
  describe "検索条件はpolicy_scopeを迂回しない" do
    let!(:group_x) { create(:agency_group, group_code: "GRPX2") }
    let!(:group_y) { create(:agency_group, group_code: "GRPY2") }
    let!(:agency_x) { create(:agency, agency_group: group_x, agency_code: "AGX2", name: "エックス東京支店") }
    let!(:agency_y) { create(:agency, agency_group: group_y, agency_code: "AGY2", name: "ワイ大阪支店") }
    let!(:other_agency_customer) { create(:customer, agency: agency_y, name: "他代理店の顧客") }
    let!(:agency_user) { user_with_role("代理店用", agency: agency_x) }

    before { sign_in_with_otp!(agency_user) }

    it "他代理店の代理店コードを直接指定しても、その顧客は見えない" do
      get admin_customers_path, params: { agency_code: "AGY2" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other_agency_customer.name)
    end

    it "他代理店グループのグループ会社コードを直接指定しても、その顧客は見えない" do
      get admin_customers_path, params: { group_code: "GRPY2" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other_agency_customer.name)
    end
  end
end

# 04 R2追補: customer_numberの自動採番の並行安全性を、spec/models/customer_spec.rbのモデル層検証に
# 加えてHTTPリクエスト経由でも検証する。Rackテストクライアント（ActionDispatch::Integration::Session）は
# スレッドセーフではないため、スレッドごとに個別のSessionインスタンスを作って独立にOTPログインしてから
# POSTする（spec/support/otp_sign_in_helper.rbのsign_in_with_otp!と同じ手順を手動で展開したもの）。
# customer_spec.rbと同じ理由でトランザクショナルフィクスチャを無効化し、afterで明示的に後片付けする。
RSpec.describe "Admin::Customers 採番の並行安全性", type: :request,
                                                    seed_permission_catalog: true, seed_status_catalog: true,
                                                    system_authorization: true do
  self.use_transactional_tests = false

  after do
    Customer.delete_all
    UserSystemRole.delete_all
    User.delete_all
    SequenceCounter.delete_all
    Agency.delete_all
    AgencyGroup.delete_all
    # トランザクショナルフィクスチャを無効化しているため、:seed_permission_catalogタグが
    # before(:each)で投入したSystemPermission/SystemRoleもロールバックされず残ってしまう。
    # role_seeder_spec.rb等「SystemRole.count等が0から始まる」前提のspecを壊さないよう明示的に消す。
    SystemRolePermission.delete_all
    SystemRole.delete_all
    SystemPermission.delete_all
  end

  it "複数スレッド・複数セッションから同時にPOSTしても customer_number が重複しない" do
    agency = create(:agency)
    admin_role = SystemRole.find_by!(name: "admin")
    # customer_spec.rbと同じ理由（プール上限に対しメインスレッドも1本消費するため4に抑える）。
    thread_count = 4
    per_thread = 2

    # OTPコードはSecureRandom.random_numberの戻り値を固定した1つの値に統一する（スレッド間で
    # 共有される単なる定数スタブなので、スレッド生成前に1回だけ設定すれば競合しない）。
    allow(SecureRandom).to receive(:random_number).and_return(123_456)

    customer_numbers = []
    mutex = Mutex.new

    threads = Array.new(thread_count) do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          # FactoryBotの内部状態（シーケンス等）はスレッドセーフ性が保証されないため、
          # spec/models/customer_spec.rb・order_spec.rbと同じ方針でスレッド内はUser.create!を直接使う。
          admin_user = User.create!(
            name: "並行admin#{i}", email: "concurrent-admin-#{i}@example.com",
            password: "Password1234", password_confirmation: "Password1234"
          )
          UserSystemRole.create!(user: admin_user, system_role: admin_role)

          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post user_session_path, params: { user: { email: admin_user.email, password: "Password1234" } }
          session.post user_otp_path, params: { code: "123456" }

          per_thread.times do |j|
            name = "並行テスト顧客#{i}-#{j}"
            session.post admin_customers_path, params: { customer: { agency_id: agency.id, name: name } }
            customer = Customer.find_by!(agency_id: agency.id, name: name)
            mutex.synchronize { customer_numbers << customer.customer_number }
          end
        end
      end
    end
    threads.each(&:join)

    expect(customer_numbers.size).to eq(thread_count * per_thread)
    expect(customer_numbers.uniq.size).to eq(thread_count * per_thread) # 重複が無いこと
  end
end
