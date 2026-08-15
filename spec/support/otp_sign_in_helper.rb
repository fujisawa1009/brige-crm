# request spec 共通ヘルパー: メールOTPログインのフロー（POST /users/sign_in -> POST /users/otp）を
# 1メソッドにまとめる（04 R0のspec/requests/admin/dashboard_spec.rbで書かれていたインラインの
# 手順をR1の複数resourceスペックで再利用するために抽出）。
#
# SecureRandom.random_numberをスタブしてOTPコードを決定的にする点も含めて共通化する。
module OtpSignInHelper
  def sign_in_with_otp!(user, password: "Password1234")
    allow(SecureRandom).to receive(:random_number).and_return(123_456)

    post user_session_path, params: { user: { email: user.email, password: password } }
    post user_otp_path, params: { code: "123456" }
  end
end

RSpec.configure do |config|
  config.include OtpSignInHelper, type: :request
end
