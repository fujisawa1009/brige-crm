require "rails_helper"

# 04 R5-1: Admin::ContractReviewsController#create（Order#transition_contract_to!の窓口）。
# OrderPolicy#transition_contract?がstaff_scope?のみを許可することを検証する
# （basic-design.md §9〜§12が「管理者が」行う工程として一貫して記述しているため）。
RSpec.describe "Admin::ContractReviews", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                          system_authorization: true do
  let!(:agency) { create(:agency) }
  let!(:contract_condition) { create(:contract_condition, agency: agency) }
  let!(:customer) { create(:customer, agency: agency) }
  let!(:order) { create(:order, agency: agency, customer: customer, contract_condition: contract_condition) }

  describe "admin(staff)はイベントを投入できる" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "check_requestedでpending_checkへ遷移し、案件詳細へリダイレクトする" do
      post admin_order_contract_reviews_path(order), params: { contract_review: { event: "check_requested" } }

      expect(response).to redirect_to(admin_order_path(order))
      expect(order.reload.contract_status).to eq(ContractStatus::CODE_PENDING_CHECK)
      expect(order.contract_reviews.sole.performed_by).to eq(admin_user)
    end

    it "定義されていない遷移はエラーメッセージ付きで案件詳細へ戻り、状態は変化しない" do
      post admin_order_contract_reviews_path(order), params: { contract_review: { event: "contract_confirmed" } }

      expect(response).to redirect_to(admin_order_path(order))
      expect(flash[:alert]).to be_present
      expect(order.reload.contract_status).to be_nil
    end

    it "reason/comment/returned_toも記録される" do
      post admin_order_contract_reviews_path(order), params: { contract_review: { event: "check_requested" } }
      post admin_order_contract_reviews_path(order),
           params: { contract_review: { event: "check_returned", reason: "住所不備", comment: "備考",
                                         returned_to: "customer" } }

      review = order.contract_reviews.order(:performed_at).last
      expect(review.reason).to eq("住所不備")
      expect(review.comment).to eq("備考")
      expect(review.returned_to).to eq("customer")
    end
  end

  describe "代理店ユーザーはイベントを投入できない（社内工程のため）" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency) }

    before { sign_in_with_otp!(agency_user) }

    it "403になり状態は変化しない" do
      post admin_order_contract_reviews_path(order), params: { contract_review: { event: "check_requested" } }

      expect(response).to have_http_status(:forbidden)
      expect(order.reload.contract_status).to be_nil
    end
  end
end
