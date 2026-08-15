require "rails_helper"

# R1完了条件: 参照制御込みでCRUD一式。一覧だけでなく詳細・更新・削除も含めてスコープ外アクセスを
# 拒否すること（01のレビューで「一覧だけ絞って詳細は無防備」という実装漏れがLaravel側で見つかった
# 教訓を踏まえる）。AgencyPolicy（app/policies/agency_policy.rb）はdestroy?のみstaff_scope?限定、
# update?はAgencyScoped既定のaccessible?（自代理店・配下代理店内の自己編集を許可）。
RSpec.describe "Admin::Agencies", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a1) { create(:agency, agency_group: group_a) }
  let!(:agency_a2) { create(:agency, agency_group: group_a) }
  let!(:agency_b)  { create(:agency, agency_group: group_b) }

  describe "admin(super_admin)は全代理店にCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全代理店が表示される" do
      get admin_agencies_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(agency_a1.name, agency_b.name)
    end

    it "他グループの代理店も詳細参照できる" do
      get admin_agency_path(agency_b)
      expect(response).to have_http_status(:ok)
    end

    it "作成できる" do
      post admin_agencies_path, params: {
        agency: { agency_group_id: group_a.id, name: "新代理店", agency_code: "NEWAGY" }
      }
      expect(response).to redirect_to(admin_agency_path(Agency.find_by!(agency_code: "NEWAGY")))
    end

    it "更新できる" do
      patch admin_agency_path(agency_b), params: { agency: { name: "更新後代理店" } }
      expect(agency_b.reload.name).to eq("更新後代理店")
    end

    it "削除できる" do
      delete admin_agency_path(agency_b)
      expect(Agency.exists?(agency_b.id)).to eq(false)
    end
  end

  describe "代理店ユーザーは自代理店のみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店のみ表示される" do
      get admin_agencies_path
      expect(response.body).to include(agency_a1.name)
      expect(response.body).not_to include(agency_a2.name)
      expect(response.body).not_to include(agency_b.name)
    end

    it "自代理店は詳細参照できる" do
      get admin_agency_path(agency_a1)
      expect(response).to have_http_status(:ok)
    end

    it "同一グループ内でも他代理店の詳細は403" do
      get admin_agency_path(agency_a2)
      expect(response).to have_http_status(:forbidden)
    end

    it "他代理店の詳細は403" do
      get admin_agency_path(agency_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店は更新できる" do
      patch admin_agency_path(agency_a1), params: { agency: { name: "自己編集後" } }
      expect(response).to redirect_to(admin_agency_path(agency_a1))
      expect(agency_a1.reload.name).to eq("自己編集後")
    end

    it "他代理店の更新は403で内容も変わらない" do
      patch admin_agency_path(agency_b), params: { agency: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(agency_b.reload.name).not_to eq("改ざん")
    end

    it "他代理店の削除は403" do
      delete admin_agency_path(agency_b)
      expect(response).to have_http_status(:forbidden)
      expect(Agency.exists?(agency_b.id)).to eq(true)
    end

    it "自代理店であっても削除は403（destroy?はstaff_scope?限定）" do
      delete admin_agency_path(agency_a1)
      expect(response).to have_http_status(:forbidden)
      expect(Agency.exists?(agency_a1.id)).to eq(true)
    end

    it "agency_group_idパラメータを送っても無視される（他グループへの付け替え防止）" do
      patch admin_agency_path(agency_a1), params: { agency: { name: "x", agency_group_id: group_b.id } }
      expect(agency_a1.reload.agency_group_id).to eq(group_a.id)
    end
  end

  describe "代理店グループユーザーは配下代理店のみ" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には配下代理店のみ表示される" do
      get admin_agencies_path
      expect(response.body).to include(agency_a1.name, agency_a2.name)
      expect(response.body).not_to include(agency_b.name)
    end

    it "配下代理店の詳細は参照できる" do
      get admin_agency_path(agency_a2)
      expect(response).to have_http_status(:ok)
    end

    it "配下外の代理店の詳細は403" do
      get admin_agency_path(agency_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "配下外の代理店の更新は403" do
      patch admin_agency_path(agency_b), params: { agency: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
