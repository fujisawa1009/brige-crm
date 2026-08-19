require "rails_helper"

# 04 R0-5・R5着手前チェックリスト「verify系」: Admin::BaseControllerへ
# after_action :verify_authorized / :verify_policy_scoped を追加した際、
# Pundit policyを持たないRBAC専有画面（admin/permission_management）が
# 誤って引っかからないこと（PUNDIT_VERIFICATION_EXEMPT_CONTROLLERS）を確認する。
# admin/permission_managementは:indexアクションを持たないため、この検証は
# 「only:/except: :index」ではなく実行時のunless:述語で行う必要があった
# （Rails 7.1のraise_on_missing_callback_actionsでAbstractController::ActionNotFoundになるバグを
#  修正した経緯がある）。
RSpec.describe "Admin::PermissionManagement", type: :request, seed_permission_catalog: true, system_authorization: true do
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

  it "admin(super_admin)は権限マトリクス画面を表示できる（verify_authorized/verify_policy_scopedで落ちない）" do
    sign_in_with_otp!(admin_user)

    get admin_permission_management_path

    expect(response).to have_http_status(:ok)
  end

  it "同期アクションもverify系フックの対象外で正常に完了する" do
    sign_in_with_otp!(admin_user)

    post sync_admin_permission_management_path

    expect(response).to redirect_to(admin_permission_management_path)
  end
end
