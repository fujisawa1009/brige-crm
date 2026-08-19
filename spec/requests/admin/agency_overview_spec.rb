require "rails_helper"

# R6-9: 代理店横断ダッシュボード。ftlogの/project_overview相当を代理店主語で単純集計する
# system_admin専有画面（admin/system_settings等と同じ「RBACのみで守られるシステム管理画面」）。
# 検証対象は (1) 集計内容（稼働中/完了/遅延/最終更新の算出が正しいこと）、
# (2) 権限（admin以外はRBACで403になること。代理店ユーザー自身には他社データを見せない要件が核心）。
RSpec.describe "Admin::AgencyOverview", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                         system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:agency_a) { create(:agency, agency_group: group_a, name: "テスト代理店A") }
  let!(:agency_b) { create(:agency, agency_group: group_a, name: "テスト代理店B") }
  let!(:cc_a) { create(:contract_condition, agency: agency_a) }
  let!(:cc_b) { create(:contract_condition, agency: agency_b) }
  let!(:customer_a) { create(:customer, agency: agency_a) }
  let!(:customer_b) { create(:customer, agency: agency_b) }

  describe "adminとしてログイン中" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "画面を表示できる（verify_authorizedで落ちない）" do
      get admin_agency_overview_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("代理店横断ダッシュボード")
      expect(response.body).to include("テスト代理店A", "テスト代理店B")
    end

    it "代理店ごとに稼働中/完了/遅延/最終更新を集計する" do
      # 稼働中2件（うち1件は work_completed_at 未到来のため遅延ではない）
      create(:order, agency: agency_a, customer: customer_a, contract_condition: cc_a)
      create(:order, agency: agency_a, customer: customer_a, contract_condition: cc_a,
                      work_completed_at: Date.current + 10)
      # 完了1件（is_completed:true の "16:完了"。過去日のwork_completed_atがあっても遅延に数えない）
      create(:order, agency: agency_a, customer: customer_a, contract_condition: cc_a, status: "16:完了",
                      work_completed_at: Date.current - 30)
      # 遅延1件（未完了 かつ work_completed_at が過去）
      create(:order, agency: agency_a, customer: customer_a, contract_condition: cc_a,
                      work_completed_at: Date.current - 5)

      get admin_agency_overview_path
      expect(response).to have_http_status(:ok)

      row = Nokogiri::HTML(response.body).css("tbody tr").find { |tr| tr.text.include?("テスト代理店A") }
      cells = row.css("td").map { |td| td.text.strip }

      # [代理店, グループ, メンバー数, 稼働中, 完了, 計, 遅延, 最終更新] の列順（view参照）。
      expect(cells[3]).to eq("3") # 稼働中（未完了3件: 通常2件+遅延1件）
      expect(cells[4]).to eq("1") # 完了1件
      expect(cells[5]).to eq("4") # 案件数（計）
      expect(cells[6]).to include("1件") # 遅延1件
    end

    it "案件が無い代理店も0件で一覧に含まれる" do
      get admin_agency_overview_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(agency_b.name)
    end
  end

  describe "admin以外はRBACで拒否される（system_admin専有）" do
    %w[実務運用者 代理店グループ用 代理店用].each do |role_name|
      it "#{role_name}ロールは表示できない（403）" do
        user =
          case role_name
          when "代理店用" then user_with_role(role_name, agency: agency_a)
          when "代理店グループ用" then user_with_role(role_name, agency_group: group_a)
          else user_with_role(role_name)
          end

        sign_in_with_otp!(user)
        get admin_agency_overview_path

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "未ログイン" do
    it "ログイン画面へリダイレクトされる" do
      get admin_agency_overview_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
