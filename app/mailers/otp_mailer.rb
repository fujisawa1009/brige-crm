class OtpMailer < ApplicationMailer
  def login_code(user, code)
    @user          = user
    @code          = code
    @valid_minutes = User::OTP_VALID_FOR.to_i / 60

    mail(to: user.email, subject: "[brige-crm] ログイン認証コード")
  end

  # 04 R3・03§8-2 Q-23: 受注入力（SalesRepresentative）ログイン用OTP。login_codeと本文構成は同じだが、
  # OTP_VALID_FORの参照元クラスが異なる（OtpAuthenticatable concernはincludeするクラスのOTP_VALID_FOR
  # 定数を見るため、User::OTP_VALID_FORをそのまま使い回すことはできない）。
  def form_login_code(sales_representative, code)
    @user          = sales_representative
    @code          = code
    @valid_minutes = SalesRepresentative::OTP_VALID_FOR.to_i / 60

    # login_code.html/text.erb をそのまま使い回す（本文は@user.name/@code/@valid_minutesのみ参照するため
    # SalesRepresentative向けに複製する必要が無い。template_nameでlogin_code用テンプレートを指定する）。
    mail(to: sales_representative.email, subject: "[brige-crm] 受注入力ログイン認証コード", template_name: "login_code")
  end
end
