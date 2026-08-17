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

  # 04 R4タスク5・03§8-2 Q-23: 顧客マイページ（Customer）ログイン用OTP。form_login_codeと同じ理由で
  # login_code.html/text.erbを使い回す（Customerも@user.name/@code/@valid_minutesの型に乗る）。
  def mypage_login_code(customer, code)
    @user          = customer
    @code          = code
    @valid_minutes = Customer::OTP_VALID_FOR.to_i / 60

    mail(to: customer.email, subject: "[brige-crm] マイページログイン認証コード", template_name: "login_code")
  end
end
