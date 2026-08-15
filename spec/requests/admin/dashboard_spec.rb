require "rails_helper"

# R0完了条件（04-implementation-plan.md）:
# 「ダッシュボード1画面が『ログイン→OTP→権限チェック→表示』を通過し、権限を剥奪すると403相当になる
#  request specがグリーン。加えて、このログイン・権限チェックイベントが監査ログに記録されていることを
#  specで確認」
RSpec.describe "Admin::Dashboard", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:role) { SystemRole.find_by!(name: "実務運用者") } # RoleSeederが admin/dashboard を既定付与する
  let(:password) { "Password1234" }
  let!(:user) do
    create(:user, password: password, password_confirmation: password).tap do |u|
      UserSystemRole.create!(user: u, system_role: role)
    end
  end

  # OTPコードを決定的にする（本番はSecureRandomでランダム生成。specでは既知の値に固定して照合する）。
  before { allow(SecureRandom).to receive(:random_number).and_return(123_456) }

  def sign_in_with_otp!
    post user_session_path, params: { user: { email: user.email, password: password } }
    expect(response).to redirect_to(new_user_otp_path) # IP許可リストが空 = 常にOTP必須（フェイルセーフ）

    post user_otp_path, params: { code: "123456" }
    expect(response).to redirect_to(root_path)
  end

  it "ログイン→OTP→権限チェックを通過してダッシュボードを表示できる" do
    sign_in_with_otp!

    get admin_dashboard_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.name)
  end

  it "権限を剥奪すると403になる" do
    sign_in_with_otp!
    revoke_system_permissions!(role, "admin/dashboard")

    get admin_dashboard_path
    expect(response).to have_http_status(:forbidden)
  end

  it "ログインイベントが監査ログ(AuditLog)に記録される" do
    sign_in_with_otp!

    events = AuditLog.where(user_id: user.id, resource_type: "User").pluck(:action)
    expect(events).to include("otp_issued", "otp_verified", "login_succeeded")
  end

  it "権限チェックのイベント自体はSystemPermissionCheckerが実認可で判定している（403 spec が保証）" do
    # このexampleは type: :request 既定の実認可（フェイルクローズ）で動いていることの明示的な確認。
    # spec/support/system_permission_authorization.rb の既定挙動そのものをテストする。
    sign_in_with_otp!
    revoke_system_permissions!(role, "admin/dashboard")

    expect(SystemPermissionChecker.allowed?(
      user: user, controller: "admin/dashboard", action: "index", http_method: "GET"
    )).to eq(false)
  end
end
