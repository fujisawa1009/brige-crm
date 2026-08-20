require "rails_helper"

# CEO指示 2026-08-20 タスク6: ページネーション未設置だった3画面
# （CSVエクスポート／ログイン履歴／店舗一覧）へ共通パーシャル shared/_pagination を導入する。
# 残り4画面（申込フォームテンプレート・重説項目セット・IP許可リスト・ロール管理）は件数が
# 少ないためCEO決定により対象外。
RSpec.describe "ページネーション未設置だった一覧画面（CEO指示 2026-08-20 タスク6）", type: :request,
                                                                                    seed_permission_catalog: true,
                                                                                    seed_status_catalog: true,
                                                                                    system_authorization: true do
  let!(:admin_user) { user_with_role("admin") }

  before { sign_in_with_otp!(admin_user) }

  describe "CSVエクスポート一覧" do
    def create_exports(count)
      count.times do |i|
        CsvExport.create!(resource_type: "Customer", requested_by: admin_user, status: "pending",
                          created_at: i.minutes.ago)
      end
    end

    it "共通ページネーションが描画される" do
      create_exports(3)

      get admin_csv_exports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<nav class="pagination"))
      expect(response.body).to include("全 3 件")
    end

    it "31件あると1ページ30件で区切られ、2ページ目のリンクが出る" do
      create_exports(31)

      get admin_csv_exports_path

      expect(response.body).to include("全 31 件中 1〜30 件を表示")
      expect(response.body).to match(/page=2[^0-9]/)
    end

    it "2ページ目に残りの1件が出る" do
      create_exports(31)

      get admin_csv_exports_path, params: { page: 2 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("全 31 件中 31〜31 件を表示")
    end
  end

  describe "ログイン履歴" do
    def create_logins(count)
      count.times do |i|
        AuditLog.create!(action: "login_succeeded", resource_type: "User", resource_id: admin_user.id,
                         resource_label: "履歴ユーザー#{i}", user_id: admin_user.id, user_type: "User",
                         ip_address: "10.0.0.#{i % 250}", created_at: i.minutes.ago)
      end
    end

    it "共通ページネーションが描画される" do
      create_logins(3)

      get admin_login_histories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<nav class="pagination"))
    end

    # ログイン自体（sign_in_with_otp!）も otp_issued / otp_verified / login_succeeded を
    # 監査ログに残すため、件数を数えるテストは resource_label の絞り込みで自分の作った行だけに寄せる。
    it "31件あると1ページ30件で区切られる" do
      create_logins(31)

      get admin_login_histories_path, params: { q: "履歴ユーザー" }

      expect(response.body).to include("全 31 件中 1〜30 件を表示")
      expect(response.body).to match(/page=2[^0-9]/)
    end

    # 従来は scope.limit(200) で直近200件しか見られず、201件目以降は画面から到達不能だった。
    # 監査用途の画面としては不適切なため、ページネーション導入に合わせて上限を撤廃した。
    it "200件を超える履歴も総件数に含まれ、201件目以降のページへ到達できる" do
      create_logins(205)

      get admin_login_histories_path, params: { q: "履歴ユーザー" }

      expect(response.body).to include("全 205 件中 1〜30 件を表示")

      get admin_login_histories_path, params: { q: "履歴ユーザー", page: 7 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("全 205 件中 181〜205 件を表示")
      expect(response.body).to include("履歴ユーザー204")
    end

    it "「上限200件」の文言は表示されない" do
      create_logins(1)

      get admin_login_histories_path

      expect(response.body).not_to include("上限200件")
      expect(response.body).not_to include("直近200件")
    end

    it "絞り込みはページ送りのリンクに引き継がれる" do
      create_logins(31)

      get admin_login_histories_path, params: { event_type: "login_succeeded" }

      expect(response.body).to include("event_type=login_succeeded")
    end
  end

  describe "店舗一覧（顧客配下のネストリソース）" do
    let!(:agency) { create(:agency) }
    let!(:customer) { create(:customer, agency: agency) }

    it "共通ページネーションが描画される" do
      create_list(:store, 3, customer: customer)

      get admin_customer_stores_path(customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<nav class="pagination"))
      expect(response.body).to include("全 3 件")
    end

    it "31件あると1ページ30件で区切られ、2ページ目へ到達できる" do
      create_list(:store, 31, customer: customer)

      get admin_customer_stores_path(customer)

      expect(response.body).to include("全 31 件中 1〜30 件を表示")
      expect(response.body).to match(/page=2[^0-9]/)

      get admin_customer_stores_path(customer), params: { page: 2 }

      expect(response.body).to include("全 31 件中 31〜31 件を表示")
    end

    it "他の顧客の店舗は総件数に含まれない" do
      other_customer = create(:customer, agency: agency)
      create_list(:store, 2, customer: customer)
      create_list(:store, 5, customer: other_customer)

      get admin_customer_stores_path(customer)

      expect(response.body).to include("全 2 件")
    end
  end
end
