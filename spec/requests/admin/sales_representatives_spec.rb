require "rails_helper"

# R1完了条件: 参照制御込みでCRUD一式。SalesRepresentativePolicy（app/policies/sales_representative_policy.rb）
# はAgencyScoped既定のまま（update?/destroy?もaccessible?＝自代理店・配下代理店内なら編集可）。
RSpec.describe "Admin::SalesRepresentatives", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a) { create(:agency, agency_group: group_a) }
  let!(:agency_b) { create(:agency, agency_group: group_b) }
  let!(:rep_a) { create(:sales_representative, agency: agency_a) }
  let!(:rep_b) { create(:sales_representative, agency: agency_b) }

  describe "admin(super_admin)は全営業担当者にCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全担当者が表示される" do
      get admin_sales_representatives_path
      expect(response.body).to include(rep_a.sales_rep_code, rep_b.sales_rep_code)
    end

    it "作成できる（sales_rep_codeはグローバルユニーク=T-2是正済み）" do
      post admin_sales_representatives_path, params: {
        sales_representative: { agency_id: agency_a.id, sales_rep_code: "NEWSR", name: "新担当" }
      }
      expect(response).to redirect_to(admin_sales_representative_path(SalesRepresentative.find_by!(sales_rep_code: "NEWSR")))
    end

    it "他代理店所属コードと重複するsales_rep_codeは作成できない（グローバルユニーク）" do
      post admin_sales_representatives_path, params: {
        sales_representative: { agency_id: agency_a.id, sales_rep_code: rep_b.sales_rep_code, name: "重複担当" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "更新できる" do
      patch admin_sales_representative_path(rep_b), params: { sales_representative: { name: "更新後担当" } }
      expect(rep_b.reload.name).to eq("更新後担当")
    end

    it "削除できる" do
      delete admin_sales_representative_path(rep_b)
      expect(SalesRepresentative.exists?(rep_b.id)).to eq(false)
    end
  end

  describe "代理店ユーザーは自代理店の担当者のみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店の担当者のみ表示される" do
      get admin_sales_representatives_path
      expect(response.body).to include(rep_a.sales_rep_code)
      expect(response.body).not_to include(rep_b.sales_rep_code)
    end

    it "自代理店の担当者は詳細参照できる" do
      get admin_sales_representative_path(rep_a)
      expect(response).to have_http_status(:ok)
    end

    it "他代理店の担当者の詳細は403" do
      get admin_sales_representative_path(rep_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店の担当者は更新できる" do
      patch admin_sales_representative_path(rep_a), params: { sales_representative: { name: "自己編集" } }
      expect(rep_a.reload.name).to eq("自己編集")
    end

    it "他代理店の担当者の更新は403" do
      patch admin_sales_representative_path(rep_b), params: { sales_representative: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(rep_b.reload.name).not_to eq("改ざん")
    end

    it "他代理店の担当者の削除は403" do
      delete admin_sales_representative_path(rep_b)
      expect(response).to have_http_status(:forbidden)
      expect(SalesRepresentative.exists?(rep_b.id)).to eq(true)
    end

    it "自代理店の担当者は削除できる" do
      delete admin_sales_representative_path(rep_a)
      expect(SalesRepresentative.exists?(rep_a.id)).to eq(false)
    end

    it "agency_idパラメータを送っても無視される（他代理店への付け替え防止）" do
      patch admin_sales_representative_path(rep_a), params: { sales_representative: { name: "x", agency_id: agency_b.id } }
      expect(rep_a.reload.agency_id).to eq(agency_a.id)
    end
  end

  describe "代理店グループユーザーは配下代理店の担当者のみ" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には配下代理店の担当者のみ表示される" do
      get admin_sales_representatives_path
      expect(response.body).to include(rep_a.sales_rep_code)
      expect(response.body).not_to include(rep_b.sales_rep_code)
    end

    it "配下外代理店の担当者の詳細は403" do
      get admin_sales_representative_path(rep_b)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
