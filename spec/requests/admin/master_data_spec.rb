require "rails_helper"

# 04 R2タスク3・4・6・8: Product/Plan/ProductInitialFee/ProductOption/OptionGroup/OptionValue/
# CustomerStatus/OrderStatus/ProductionCompany/SalesMaterial共通のMasterDataPolicy挙動を検証する。
# 「代理店スコープ対象外＝全代理店共通閲覧でよい。作成・変更は実務運用者以上に限定」（04 R2タスク8）。
#
# 実装メモ: 当初「[表示名, パスlambda, レコード生成lambda]の配列をeachで回してdescribeを動的生成する」
# 形で書いたが、配列内のlambdaがブロック展開のタイミングでexample groupコンテキスト扱いになり
# FactoryBotの`create`がグループレベル呼び出しとして拒否される問題が起きたため、単純な繰り返し記述に
# 差し戻した（過剰な抽象化よりも動作確実性を優先。CTO判断）。
RSpec.describe "Admin::MasterData", type: :request, seed_permission_catalog: true, system_authorization: true do
  shared_examples "master data read access" do
    context "実務運用者（staff）" do
      let!(:staff_user) { user_with_role("実務運用者") }

      before { sign_in_with_otp!(staff_user) }

      it "一覧が閲覧できる" do
        get index_path
        expect(response).to have_http_status(:ok)
      end

      it "詳細が閲覧できる" do
        get show_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "代理店ユーザー" do
      let!(:agency_user) { user_with_role("代理店用", agency: create(:agency)) }

      before { sign_in_with_otp!(agency_user) }

      it "一覧は閲覧できる（代理店スコープ対象外）" do
        get index_path
        expect(response).to have_http_status(:ok)
      end

      it "詳細も閲覧できる" do
        get show_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "products" do
    let!(:record) { create(:product) }
    let(:index_path) { admin_products_path }
    let(:show_path) { admin_product_path(record) }

    include_examples "master data read access"
  end

  describe "plans" do
    let!(:record) { create(:plan) }
    let(:index_path) { admin_plans_path }
    let(:show_path) { admin_plan_path(record) }

    include_examples "master data read access"
  end

  describe "product_initial_fees" do
    let!(:record) { create(:product_initial_fee) }
    let(:index_path) { admin_product_initial_fees_path }
    let(:show_path) { admin_product_initial_fee_path(record) }

    include_examples "master data read access"
  end

  describe "product_options" do
    let!(:record) { create(:product_option) }
    let(:index_path) { admin_product_options_path }
    let(:show_path) { admin_product_option_path(record) }

    include_examples "master data read access"
  end

  describe "option_groups" do
    let!(:record) { create(:option_group) }
    let(:index_path) { admin_option_groups_path }
    let(:show_path) { admin_option_group_path(record) }

    include_examples "master data read access"
  end

  describe "option_values" do
    let!(:record) { create(:option_value) }
    let(:index_path) { admin_option_values_path }
    let(:show_path) { admin_option_value_path(record) }

    include_examples "master data read access"
  end

  describe "customer_statuses" do
    let!(:record) { create(:customer_status) }
    let(:index_path) { admin_customer_statuses_path }
    let(:show_path) { admin_customer_status_path(record) }

    include_examples "master data read access"
  end

  describe "order_statuses" do
    let!(:record) { create(:order_status) }
    let(:index_path) { admin_order_statuses_path }
    let(:show_path) { admin_order_status_path(record) }

    include_examples "master data read access"
  end

  describe "production_companies" do
    let!(:record) { create(:production_company) }
    let(:index_path) { admin_production_companies_path }
    let(:show_path) { admin_production_company_path(record) }

    include_examples "master data read access"
  end

  describe "sales_materials" do
    let!(:record) { create(:sales_material) }
    let(:index_path) { admin_sales_materials_path }
    let(:show_path) { admin_sales_material_path(record) }

    include_examples "master data read access"
  end

  describe "代理店ユーザーはマスタ系の作成ができない（create?はstaff_scope?限定）" do
    let!(:agency_user) { user_with_role("代理店用", agency: create(:agency)) }

    before { sign_in_with_otp!(agency_user) }

    it "商材の新規作成は403" do
      post admin_products_path, params: { product: { name: "不正商材", code: "BAD" } }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
