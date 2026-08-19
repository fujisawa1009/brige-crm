require "rails_helper"

# R6-8 ファイル管理基盤・完了条件（タスク指示書）: 「is_visible_to_customer=falseのファイルへ
# 顧客経路から到達できないこと」をrequest specで確認する。マイページにOrder詳細画面が無いため
# ダウンロード経路のみを検証する（Mypage::OrderAttachmentsControllerのコメント参照）。
# 他顧客のOrderの添付ファイルへ到達できないこと（IDOR）も、Mypage::Dashboard specと同じ観点で確認する。
RSpec.describe "Mypage::OrderAttachments", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                            system_authorization: true do
  let!(:agency) { create(:agency) }
  let!(:customer_a) { create(:customer, agency: agency) }
  let!(:customer_b) { create(:customer, agency: agency) }
  let!(:order_a) { create(:order, agency: agency, customer: customer_a) }
  let!(:order_b) { create(:order, agency: agency, customer: customer_b) }
  let!(:visible_attachment)   { create(:order_attachment, order: order_a, is_visible_to_customer: true) }
  let!(:hidden_attachment)    { create(:order_attachment, order: order_a, is_visible_to_customer: false) }
  let!(:other_customer_attachment) { create(:order_attachment, order: order_b, is_visible_to_customer: true) }

  it "未ログインではダウンロードできない（ログイン画面へリダイレクト）" do
    get download_mypage_order_attachment_path(visible_attachment)
    expect(response).to redirect_to(new_customer_session_path)
  end

  context "顧客Aとしてログイン中" do
    before { sign_in(customer_a, scope: :customer) }

    it "自分のOrderのis_visible_to_customer=trueなファイルはダウンロードできる" do
      get download_mypage_order_attachment_path(visible_attachment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("dummy file content")
    end

    it "自分のOrderでもis_visible_to_customer=falseなファイルへは到達できない" do
      # config.action_dispatch.show_exceptions = :rescuable（test環境）により、controller内で
      # 起きたActiveRecord::RecordNotFoundはRSpecのブロックへ生の例外として伝播せず404レスポンスに
      # 変換される（consider_all_requests_local=trueのため例外ページがbodyになる）。よって
      # raise_errorではなくレスポンスのステータスで判定する。
      get download_mypage_order_attachment_path(hidden_attachment)
      expect(response).to have_http_status(:not_found)
    end

    it "他顧客のOrderの添付ファイル（is_visible_to_customer=trueでも）へは到達できない" do
      get download_mypage_order_attachment_path(other_customer_attachment)
      expect(response).to have_http_status(:not_found)
    end
  end
end
