require "rails_helper"

# 04 R3タスク1・2: 受注入力ログイン（代理店CD＋営業担当者CD→メールOTP）。
RSpec.describe "Form::Sessions", type: :request do
  let!(:agency) { create(:agency) }
  let!(:sales_representative) { create(:sales_representative, agency: agency, email: "rep@example.com") }

  before { allow(SecureRandom).to receive(:random_number).and_return(123_456) }

  it "正しい代理店CD・営業担当者CDでOTP待ちに遷移する" do
    post form_sessions_path,
         params: { agency_code: agency.agency_code, sales_rep_code: sales_representative.sales_rep_code }
    expect(response).to redirect_to(form_new_otp_path)
  end

  it "OTP照合に成功するとセッションが確立し商材選択画面へ遷移する" do
    post form_sessions_path,
         params: { agency_code: agency.agency_code, sales_rep_code: sales_representative.sales_rep_code }
    post form_otp_path, params: { code: "123456" }
    expect(response).to redirect_to(form_new_application_path)

    get form_new_application_path
    expect(response).to have_http_status(:ok)
  end

  it "誤った営業担当者CDは422で再入力を促す" do
    post form_sessions_path, params: { agency_code: agency.agency_code, sales_rep_code: "WRONG-CODE" }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "他代理店の営業担当者CDでは本人特定できない（代理店CDとの組み合わせが認証キー）" do
    other_agency = create(:agency)
    post form_sessions_path,
         params: { agency_code: other_agency.agency_code, sales_rep_code: sales_representative.sales_rep_code }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "無効化(is_active=false)された営業担当者はログインできない" do
    sales_representative.update!(is_active: false)
    post form_sessions_path,
         params: { agency_code: agency.agency_code, sales_rep_code: sales_representative.sales_rep_code }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "メールアドレス未設定の営業担当者はOTP送信先が無いためログインできない" do
    sales_representative.update!(email: nil)
    post form_sessions_path,
         params: { agency_code: agency.agency_code, sales_rep_code: sales_representative.sales_rep_code }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "ログイン・OTPイベントが監査ログ(AuditLog)に記録される" do
    post form_sessions_path,
         params: { agency_code: agency.agency_code, sales_rep_code: sales_representative.sales_rep_code }
    post form_otp_path, params: { code: "123456" }

    actions = AuditLog.where(user_id: sales_representative.id, user_type: "SalesRepresentative").pluck(:action)
    expect(actions).to include("otp_issued", "otp_verified")
  end
end
