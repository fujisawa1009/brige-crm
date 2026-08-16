require "rails_helper"

# R1完了条件（04-implementation-plan.md）: 参照制御込みでCRUD一式。
# AgencyGroupPolicy（app/policies/agency_group_policy.rb）は代理店担当者を常にaccessible?=falseとし、
# update?/destroy?は代理店グループ担当者にも許可しない（staff_scope?のみ）。
RSpec.describe "Admin::AgencyGroups", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }

  describe "admin(super_admin)は全代理店グループにCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全グループが表示される" do
      get admin_agency_groups_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(group_a.name, group_b.name)
    end

    it "作成できる" do
      post admin_agency_groups_path, params: {
        agency_group: { name: "新グループ", service_type: "BridgePlus", group_code: "NEWGRP" }
      }
      expect(response).to redirect_to(admin_agency_group_path(AgencyGroup.find_by!(group_code: "NEWGRP")))
    end

    it "更新できる" do
      patch admin_agency_group_path(group_b), params: { agency_group: { name: "更新後グループ" } }
      expect(response).to redirect_to(admin_agency_group_path(group_b))
      expect(group_b.reload.name).to eq("更新後グループ")
    end

    it "削除できる" do
      delete admin_agency_group_path(group_b)
      expect(AgencyGroup.exists?(group_b.id)).to eq(false)
    end

    it "配下にユーザーがいる代理店グループは削除できない（R1修正: 削除でagency_group_idがNULL化され" \
       "配下ユーザーがstaff権限に昇格する権限昇格バグの防止）" do
      sub_user = create(:user, agency_group: group_b)

      delete admin_agency_group_path(group_b)

      expect(response).to redirect_to(admin_agency_group_path(group_b))
      expect(AgencyGroup.exists?(group_b.id)).to eq(true)
      expect(sub_user.reload.agency_group_id).to eq(group_b.id)
    end
  end

  describe "代理店グループユーザーは自グループのみ閲覧可・更新/削除は不可" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には自グループのみ表示される" do
      get admin_agency_groups_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(group_a.name)
      expect(response.body).not_to include(group_b.name)
    end

    it "自グループは詳細参照できる" do
      get admin_agency_group_path(group_a)
      expect(response).to have_http_status(:ok)
    end

    it "他グループの詳細は403" do
      get admin_agency_group_path(group_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "自グループであっても更新は403（組織設定は代理店側に自己編集させない方針）" do
      patch admin_agency_group_path(group_a), params: { agency_group: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(group_a.reload.name).not_to eq("改ざん")
    end
  end

  describe "代理店ユーザーはAgencyGroupに一切アクセスできない" do
    let!(:agency) { create(:agency, agency_group: group_a) }
    let!(:agency_user) { user_with_role("代理店用", agency: agency) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧は空になる" do
      get admin_agency_groups_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(group_a.name)
      expect(response.body).not_to include(group_b.name)
    end

    it "自代理店が属するグループの詳細も403" do
      get admin_agency_group_path(group_a)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
