require "rails_helper"

# R1完了条件: 参照制御込みでCRUD一式。ContractConditionPolicy（app/policies/contract_condition_policy.rb）
# は契約条件＝商取引条件そのものという性質上、update?/destroy?もstaff_scope?限定（代理店に自己編集
# させない）。index?/show?はAgencyScoped既定のaccessible?（自代理店・配下代理店内は閲覧可）。
#
# 申し送り（T-3）: R1では Agency 1─* ContractCondition の単体CRUDのみ。Order側への紐づけはR2で追加。
RSpec.describe "Admin::ContractConditions", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:agency_a) { create(:agency, agency_group: group_a) }
  let!(:agency_b) { create(:agency) }
  let!(:condition_a) { create(:contract_condition, agency: agency_a, name: "条件A") }
  let!(:condition_b) { create(:contract_condition, agency: agency_b, name: "条件B") }

  describe "admin(super_admin)は全契約条件にCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全件表示される" do
      get admin_contract_conditions_path
      expect(response.body).to include(condition_a.name, condition_b.name)
    end

    it "作成できる" do
      post admin_contract_conditions_path, params: {
        contract_condition: { agency_id: agency_a.id, name: "新条件", effective_from: Date.current }
      }
      expect(response).to redirect_to(admin_contract_condition_path(ContractCondition.find_by!(name: "新条件")))
    end

    it "更新できる" do
      patch admin_contract_condition_path(condition_b), params: { contract_condition: { name: "更新後条件" } }
      expect(condition_b.reload.name).to eq("更新後条件")
    end

    it "削除できる" do
      delete admin_contract_condition_path(condition_b)
      expect(ContractCondition.exists?(condition_b.id)).to eq(false)
    end
  end

  describe "代理店ユーザーは自代理店の契約条件を閲覧のみ可能（編集不可）" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店の契約条件のみ表示される" do
      get admin_contract_conditions_path
      expect(response.body).to include(condition_a.name)
      expect(response.body).not_to include(condition_b.name)
    end

    it "自代理店の契約条件は詳細参照できる" do
      get admin_contract_condition_path(condition_a)
      expect(response).to have_http_status(:ok)
    end

    it "他代理店の契約条件の詳細は403" do
      get admin_contract_condition_path(condition_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店の契約条件であっても更新は403（自己有利な条件への書き換え防止）" do
      patch admin_contract_condition_path(condition_a), params: { contract_condition: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(condition_a.reload.name).not_to eq("改ざん")
    end

    it "自代理店の契約条件であっても削除は403" do
      delete admin_contract_condition_path(condition_a)
      expect(response).to have_http_status(:forbidden)
      expect(ContractCondition.exists?(condition_a.id)).to eq(true)
    end
  end
end
