require "rails_helper"

# 04 R3タスク1: 「form sectionがauthorize_system_permission!をスキップしつつ、FormAuth未ログイン状態では
# adminのRBAC権限に関わらずアクセス拒否されることを確認する」（R3完了条件・03§8-2認可統合決定(b)）。
# authorize_system_permission!はform配下を完全スキップするため、この名前空間を守れるのは
# FormAuthenticatable concernだけである。ここが機能していないとRBACの穴（誰でも受注入力に到達できる）
# になるため、admin(super_admin)の管理画面ログインを持ってしても迂回できないことまで検証する。
RSpec.describe "Form section access control", type: :request, seed_permission_catalog: true do
  it "FormAuth未ログインならログイン画面へリダイレクトされる（未認証の素通し防止）" do
    get form_new_application_path
    expect(response).to redirect_to(form_new_session_path)
  end

  it "admin(super_admin)で管理画面にログイン済みでも、FormAuthセッションが無ければform配下に到達できない" do
    admin_role = SystemRole.find_by!(name: "admin")
    password   = "Password1234"
    admin_user = create(:user, password: password, password_confirmation: password)
    UserSystemRole.create!(user: admin_user, system_role: admin_role)

    allow(SecureRandom).to receive(:random_number).and_return(123_456)
    post user_session_path, params: { user: { email: admin_user.email, password: password } }
    post user_otp_path, params: { code: "123456" }
    expect(response).to redirect_to(root_path) # 管理画面ログイン自体には成功している

    # authorize_system_permission!はform名前空間を完全スキップする（03§8-2決定b）ため403にはならないが、
    # FormAuthenticatable（独自ミドルウェア）がSalesRepresentativeセッション不在で弾く。
    get form_new_application_path
    expect(response).to redirect_to(form_new_session_path)
  end
end
