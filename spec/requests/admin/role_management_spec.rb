require "rails_helper"

# 04 R0-5・R5着手前チェックリスト「verify系」: Admin::BaseControllerへ
# after_action :verify_authorized / :verify_policy_scoped を追加した際、
# Pundit policyを持たないRBAC専有画面（admin/role_management）が誤って引っかからないこと
# （PUNDIT_VERIFICATION_EXEMPT_CONTROLLERS）を確認する。permission_management_spec.rbと同型。
RSpec.describe "Admin::RoleManagement", type: :request, seed_permission_catalog: true, system_authorization: true do
  let(:password) { "Password1234" }
  let!(:admin_user) do
    admin_role = SystemRole.find_by!(name: "admin")
    create(:user, password: password, password_confirmation: password).tap do |u|
      UserSystemRole.create!(user: u, system_role: admin_role)
    end
  end

  before { allow(SecureRandom).to receive(:random_number).and_return(123_456) }

  def sign_in_with_otp!(user)
    post user_session_path, params: { user: { email: user.email, password: password } }
    post user_otp_path, params: { code: "123456" }
  end

  it "admin(super_admin)はロール一覧を表示できる（verify_authorized/verify_policy_scopedで落ちない）" do
    sign_in_with_otp!(admin_user)

    get admin_role_management_index_path

    expect(response).to have_http_status(:ok)
  end

  it "新規ロール作成画面を表示できる" do
    sign_in_with_otp!(admin_user)

    get new_admin_role_management_path

    expect(response).to have_http_status(:ok)
  end

  it "新規ロールを作成できる（verify系フックの対象外）" do
    sign_in_with_otp!(admin_user)

    post admin_role_management_index_path, params: { system_role: { name: "テストロール", display_name: "テストロール" } }

    expect(response).to redirect_to(admin_role_management_index_path)
    expect(SystemRole.exists?(name: "テストロール")).to be true
  end

  it "並び替え(reorder)もverify系フックの対象外で正常に完了する" do
    sign_in_with_otp!(admin_user)
    role = SystemRole.find_by!(name: "実務運用者")

    post reorder_admin_role_management_index_path, params: { ids: [ role.id ] }

    expect(response).to have_http_status(:ok)
  end
end
