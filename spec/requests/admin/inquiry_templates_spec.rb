require "rails_helper"

# R6-4: 問い合わせ返信テンプレート管理。NotificationTemplate同様の内部運用マスタ
# （実務運用者専有・代理店/代理店グループは到達不可）であることと、CRUDの基本動作を検証する。
RSpec.describe "Admin::InquiryTemplates", type: :request, seed_permission_catalog: true,
                                           system_authorization: true do
  let!(:staff_user) { user_with_role("実務運用者") }

  describe "実務運用者（内部スタッフ）" do
    before { sign_in_with_otp!(staff_user) }

    it "一覧・新規フォームにアクセスできる" do
      get admin_inquiry_templates_path
      expect(response).to have_http_status(:ok)
      get new_admin_inquiry_template_path
      expect(response).to have_http_status(:ok)
    end

    it "カテゴリ・名称・本文を指定して作成できる" do
      post admin_inquiry_templates_path, params: {
        inquiry_template: {
          category: InquiryTemplate::CATEGORIES.first,
          name: "ログインできない場合の案内",
          body: "%{customer_name}様、ログイン情報を再送いたします。"
        }
      }

      template = InquiryTemplate.find_by(name: "ログインできない場合の案内")
      expect(template).to be_present
      expect(response).to redirect_to(admin_inquiry_template_path(template))
    end

    it "categoryが不正だとエラーで再表示され、作成されない" do
      expect {
        post admin_inquiry_templates_path, params: {
          inquiry_template: { category: "存在しないカテゴリ", name: "不正テンプレ", body: "本文" }
        }
      }.not_to change(InquiryTemplate, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "更新・削除できる" do
      template = create(:inquiry_template)

      patch admin_inquiry_template_path(template), params: { inquiry_template: { name: "更新後の名前" } }
      expect(template.reload.name).to eq("更新後の名前")

      expect {
        delete admin_inquiry_template_path(template)
      }.to change(InquiryTemplate, :count).by(-1)
    end

    it "categoryで絞り込める" do
      create(:inquiry_template, category: "ログイン情報関連", name: "ログイン系テンプレ")
      create(:inquiry_template, category: "通知関連", name: "通知系テンプレ")

      get admin_inquiry_templates_path, params: { category: "ログイン情報関連" }
      expect(response.body).to include("ログイン系テンプレ")
      expect(response.body).not_to include("通知系テンプレ")
    end
  end

  describe "代理店ユーザー（内部運用専有のため到達不可）" do
    let!(:agency) { create(:agency) }
    let!(:agency_user) { user_with_role("代理店用", agency: agency) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧は403" do
      get admin_inquiry_templates_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "代理店グループユーザー（内部運用専有のため到達不可）" do
    let!(:agency_group) { create(:agency_group) }
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: agency_group) }

    before { sign_in_with_otp!(group_user) }

    it "一覧は403" do
      get admin_inquiry_templates_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
