# request spec 共通ヘルパー: 受注入力（営業担当者）のメールOTPログインフロー
# （POST /form/login -> POST /form/otp）を1メソッドにまとめる（spec/support/otp_sign_in_helper.rbの
# SalesRepresentative版）。
module FormAuthHelper
  def sign_in_sales_representative_with_otp!(sales_representative, agency_code: sales_representative.agency.agency_code)
    allow(SecureRandom).to receive(:random_number).and_return(123_456)

    post form_sessions_path, params: { agency_code: agency_code, sales_rep_code: sales_representative.sales_rep_code }
    post form_otp_path, params: { code: "123456" }
  end
end

RSpec.configure do |config|
  config.include FormAuthHelper, type: :request
end
