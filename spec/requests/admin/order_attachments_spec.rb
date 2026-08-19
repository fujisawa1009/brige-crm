require "rails_helper"

# R6-8 ファイル管理基盤・完了条件（タスク指示書）: 「他代理店のOrderの添付ファイルをダウンロード
# できないこと」をrequest specで確認する（R1〜R6-5で確立されたAgencyScoped参照制御パターンの適用）。
# アップロード(create)・削除(destroy)はOrderAttachmentPolicyの既定どおりstaff_scope?限定
# （create?はAgencyScoped既定のまま、destroy?はAgencyGroup/ContractConditionと同じ理由で
# staff_scope?へ上書き。app/policies/order_attachment_policy.rb参照）であることも合わせて確認する。
RSpec.describe "Admin::OrderAttachments", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                           system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a1) { create(:agency, agency_group: group_a) }
  let!(:agency_a2) { create(:agency, agency_group: group_a) }
  let!(:agency_b)  { create(:agency, agency_group: group_b) }
  let!(:customer_a1) { create(:customer, agency: agency_a1) }
  let!(:customer_a2) { create(:customer, agency: agency_a2) }
  let!(:customer_b)  { create(:customer, agency: agency_b) }
  let!(:order_a1) { create(:order, agency: agency_a1, customer: customer_a1) }
  let!(:order_a2) { create(:order, agency: agency_a2, customer: customer_a2) }
  let!(:order_b)  { create(:order, agency: agency_b, customer: customer_b) }
  let!(:attachment_a1) { create(:order_attachment, order: order_a1) }
  let!(:attachment_b)  { create(:order_attachment, order: order_b) }

  describe "アップロード(create)" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

    it "admin(実務運用者相当)はファイルをアップロードできる" do
      sign_in_with_otp!(admin_user)

      expect {
        post admin_order_order_attachments_path(order_a1), params: {
          order_attachment: { file: dummy_upload_file, file_type: "契約書", is_visible_to_customer: "1" }
        }
      }.to change { order_a1.order_attachments.count }.by(1)

      expect(response).to redirect_to(admin_order_path(order_a1))
      created = order_a1.order_attachments.order(created_at: :desc).first
      expect(created.file_type).to eq("契約書")
      expect(created.is_visible_to_customer).to eq(true)
    end

    it "アップロードしなければis_visible_to_customerは既定でfalse（社内限定）になる" do
      sign_in_with_otp!(admin_user)

      post admin_order_order_attachments_path(order_a1), params: {
        order_attachment: { file: dummy_upload_file }
      }

      created = order_a1.order_attachments.order(created_at: :desc).first
      expect(created.is_visible_to_customer).to eq(false)
    end

    it "代理店ユーザーは自代理店のOrderへも403でアップロードできない（OrderAttachmentPolicy#create?がstaff_scope?限定）" do
      sign_in_with_otp!(agency_user)

      expect {
        post admin_order_order_attachments_path(order_a1), params: {
          order_attachment: { file: dummy_upload_file }
        }
      }.not_to change { order_a1.order_attachments.count }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "ダウンロード(download)" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_a1_user) { user_with_role("代理店用", agency: agency_a1) }
    let!(:agency_a2_user) { user_with_role("代理店用", agency: agency_a2) }
    let!(:group_a_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    it "adminは任意のOrderの添付ファイルをダウンロードできる" do
      sign_in_with_otp!(admin_user)

      get download_admin_order_order_attachment_path(order_b, attachment_b)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("dummy file content")
    end

    it "代理店ユーザーは自代理店のOrderの添付ファイルをダウンロードできる" do
      sign_in_with_otp!(agency_a1_user)

      get download_admin_order_order_attachment_path(order_a1, attachment_a1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("dummy file content")
    end

    it "他代理店のOrderの添付ファイルはダウンロードできない（403）" do
      sign_in_with_otp!(agency_a2_user)

      get download_admin_order_order_attachment_path(order_a1, attachment_a1)

      expect(response).to have_http_status(:forbidden)
    end

    it "グループ外代理店（agency_b）のOrderの添付ファイルもダウンロードできない（403）" do
      sign_in_with_otp!(agency_a2_user)

      get download_admin_order_order_attachment_path(order_b, attachment_b)

      expect(response).to have_http_status(:forbidden)
    end

    it "代理店グループユーザーは配下代理店のOrderの添付ファイルをダウンロードできる" do
      sign_in_with_otp!(group_a_user)

      get download_admin_order_order_attachment_path(order_a1, attachment_a1)

      expect(response).to have_http_status(:ok)
    end

    it "代理店グループユーザーは配下外代理店のOrderの添付ファイルをダウンロードできない（403）" do
      sign_in_with_otp!(group_a_user)

      get download_admin_order_order_attachment_path(order_b, attachment_b)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "削除(destroy)" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_a1_user) { user_with_role("代理店用", agency: agency_a1) }

    it "adminは削除できる" do
      sign_in_with_otp!(admin_user)

      expect {
        delete admin_order_order_attachment_path(order_a1, attachment_a1)
      }.to change { order_a1.order_attachments.count }.by(-1)

      expect(response).to redirect_to(admin_order_path(order_a1))
    end

    it "自代理店のOrderの添付ファイルでも代理店ユーザーは削除できない（403。契約書等を自己判断で失わせない設計）" do
      sign_in_with_otp!(agency_a1_user)

      expect {
        delete admin_order_order_attachment_path(order_a1, attachment_a1)
      }.not_to change { order_a1.order_attachments.count }

      expect(response).to have_http_status(:forbidden)
    end
  end

  def dummy_upload_file
    file = Tempfile.new([ "order_attachment", ".txt" ])
    file.write("uploaded content")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/plain")
  end
end
