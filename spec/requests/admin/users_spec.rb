require "rails_helper"

# R1完了条件: 参照制御込みでCRUD一式。UserPolicy（app/policies/user_policy.rb）はAgencyScoped既定
# のまま（create?=staff_scope?のみ・update?/destroy?はaccessible?＝自スコープ内のサブアカウント
# 管理を許可）。CSV一括アップロード（04 R1タスク5）もあわせて確認する。
RSpec.describe "Admin::Users", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a) { create(:agency, agency_group: group_a) }
  let!(:agency_b) { create(:agency, agency_group: group_b) }

  describe "admin(super_admin)は全ユーザーにCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:sub_user)   { user_with_role("代理店用", agency: agency_b) }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全ユーザーが表示される" do
      get admin_users_path
      expect(response.body).to include(admin_user.email, sub_user.email)
    end

    it "作成できる（agency_idを指定して代理店担当者を発行）" do
      post admin_users_path, params: {
        user: {
          name: "新規代理店ユーザー", email: "new-agency-user@example.com",
          password: "Password1234", password_confirmation: "Password1234",
          agency_id: agency_a.id
        }
      }
      created = User.find_by!(email: "new-agency-user@example.com")
      expect(response).to redirect_to(admin_user_path(created))
      expect(created.agency_id).to eq(agency_a.id)
    end

    it "更新できる" do
      patch admin_user_path(sub_user), params: { user: { name: "更新後ユーザー" } }
      expect(sub_user.reload.name).to eq("更新後ユーザー")
    end

    it "削除できる" do
      delete admin_user_path(sub_user)
      expect(User.exists?(sub_user.id)).to eq(false)
    end
  end

  describe "代理店ユーザーは自代理店のサブアカウントのみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a) }
    let!(:same_agency_sub) { user_with_role("代理店用", agency: agency_a) }
    let!(:other_agency_sub) { user_with_role("代理店用", agency: agency_b) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店のユーザーのみ表示される" do
      get admin_users_path
      expect(response.body).to include(agency_user.email, same_agency_sub.email)
      expect(response.body).not_to include(other_agency_sub.email)
    end

    it "自代理店のユーザーは詳細参照できる" do
      get admin_user_path(same_agency_sub)
      expect(response).to have_http_status(:ok)
    end

    it "他代理店のユーザーの詳細は403" do
      get admin_user_path(other_agency_sub)
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店のユーザーは更新できる" do
      patch admin_user_path(same_agency_sub), params: { user: { name: "自己編集" } }
      expect(same_agency_sub.reload.name).to eq("自己編集")
    end

    it "他代理店のユーザーの更新は403" do
      patch admin_user_path(other_agency_sub), params: { user: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(other_agency_sub.reload.name).not_to eq("改ざん")
    end

    it "他代理店のユーザーの削除は403" do
      delete admin_user_path(other_agency_sub)
      expect(response).to have_http_status(:forbidden)
      expect(User.exists?(other_agency_sub.id)).to eq(true)
    end

    it "作成は403（新規アカウント発行はstaffのみ）" do
      post admin_users_path, params: {
        user: {
          name: "勝手に発行", email: "unauthorized@example.com",
          password: "Password1234", password_confirmation: "Password1234"
        }
      }
      expect(response).to have_http_status(:forbidden)
      expect(User.exists?(email: "unauthorized@example.com")).to eq(false)
    end

    it "agency_idパラメータを送っても無視される（他代理店への付け替え防止）" do
      patch admin_user_path(same_agency_sub), params: { user: { name: "x", agency_id: agency_b.id } }
      expect(same_agency_sub.reload.agency_id).to eq(agency_a.id)
    end
  end

  describe "代理店グループユーザーは配下代理店のユーザーも参照できる" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }
    let!(:member_sub) { user_with_role("代理店用", agency: agency_a) }
    let!(:other_sub)  { user_with_role("代理店用", agency: agency_b) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には自分自身と配下代理店のユーザーが表示される" do
      get admin_users_path
      expect(response.body).to include(group_user.email, member_sub.email)
      expect(response.body).not_to include(other_sub.email)
    end

    it "配下外代理店のユーザーの詳細は403" do
      get admin_user_path(other_sub)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "CSV一括アップロード（04 R1タスク5）" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a) }

    it "staffはCSVをアップロードすると非同期ジョブが投入される" do
      sign_in_with_otp!(admin_user)
      csv = "name,email,password,agency_id\n新CSVユーザー,csv-user@example.com,,#{agency_a.id}\n"

      expect {
        post import_upload_admin_users_path, params: { csv_file: fixture_file_csv(csv) }
      }.to have_enqueued_job(UserCsvImportJob)

      expect(response).to redirect_to(admin_users_path)
    end

    it "代理店ユーザーはCSVアップロードできない（403）" do
      sign_in_with_otp!(agency_user)
      csv = "name,email,password,agency_id\n新CSVユーザー,csv-user2@example.com,,#{agency_a.id}\n"

      expect {
        post import_upload_admin_users_path, params: { csv_file: fixture_file_csv(csv) }
      }.not_to have_enqueued_job(UserCsvImportJob)

      expect(response).to have_http_status(:forbidden)
    end

    it "ジョブを実行すると各行がUserとして作成される" do
      csv = "name,email,password,agency_id\nCSVユーザー1,csv-import-1@example.com,,#{agency_a.id}\n" \
            "CSVユーザー2,csv-import-2@example.com,Password1234,\n"

      expect { UserCsvImportJob.perform_now(csv, requested_by_user_id: admin_user.id) }
        .to change(User, :count).by(2)

      created = User.find_by!(email: "csv-import-1@example.com")
      expect(created.agency_id).to eq(agency_a.id)
      expect(created.is_active).to eq(true)
    end

    it "1行がDB制約違反（存在しないagency_id）でも他の行は処理を継続する（PostgreSQLの" \
       "トランザクション中断対策=requires_new savepointの検証）" do
      csv = "name,email,password,agency_id\n" \
            "存在しない代理店担当,not-an-agency@example.com,Password1234,#{SecureRandom.uuid}\n" \
            "CSVユーザー3,csv-import-3@example.com,Password1234,\n"

      expect { UserCsvImportJob.perform_now(csv, requested_by_user_id: admin_user.id) }
        .to change(User, :count).by(1)

      expect(User.exists?(email: "not-an-agency@example.com")).to eq(false)
      expect(User.exists?(email: "csv-import-3@example.com")).to eq(true)
    end
  end

  # multipart アップロード用の一時CSVファイルを作る（Rack::Test::UploadedFileはパス指定が確実なため
  # Tempfileを経由する。exampleのトランザクションと無関係に自動削除されるOSの一時領域を使う）。
  def fixture_file_csv(content)
    file = Tempfile.new([ "users", ".csv" ])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv")
  end
end
