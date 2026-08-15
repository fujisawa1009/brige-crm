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
end
