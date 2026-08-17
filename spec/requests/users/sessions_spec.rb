require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  let(:password) { "Password1234" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  it "パスワードが正しくてもIP許可リストが空ならOTP待ちに遷移する（P4-17フェイルセーフ）" do
    post user_session_path, params: { user: { email: user.email, password: password } }
    expect(response).to redirect_to(new_user_otp_path)
  end

  it "パスワードが誤っていればログイン失敗が監査ログに記録される" do
    post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }
    expect(AuditLog.where(user_id: user.id, action: "login_failed")).to exist
  end

  it "接続元IPが許可リストに含まれていればOTPをスキップして即ログインする" do
    IpAllowlistEntry.create!(cidr: "127.0.0.1/32")

    post user_session_path, params: { user: { email: user.email, password: password } }
    expect(response).to redirect_to(root_path)
    expect(AuditLog.where(user_id: user.id, action: "login_succeeded")).to exist
  end

  # 2026-08-17見直しレビューで発見した重大な脆弱性の回帰テスト:
  # ApplicationControllerのauthenticate_user!・set_current_attributesがdevise_controller?（本コントローラ）
  # にも無条件に適用されていたため、current_user呼び出しがparams[:user][:email]/[:password]を使って
  # Wardenのstrategyを（store: falseなしで）先に実行してしまい、OTP完了前でも実質ログイン済みになり、
  # 保護されたページへ直接到達できてしまっていた（2要素認証のバイパス）。Docker環境で実際に再現確認済み。
  it "OTP未完了の間はadmin/dashboard等の保護されたページへ到達できない（2要素認証バイパスの回帰防止）",
     seed_permission_catalog: true, system_authorization: true do
    role = SystemRole.find_by!(name: "実務運用者")
    UserSystemRole.create!(user: user, system_role: role)

    post user_session_path, params: { user: { email: user.email, password: password } }
    expect(response).to redirect_to(new_user_otp_path)

    get admin_dashboard_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
