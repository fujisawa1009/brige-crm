class OtpMailer < ApplicationMailer
  def login_code(user, code)
    @user          = user
    @code          = code
    @valid_minutes = User::OTP_VALID_FOR.to_i / 60

    mail(to: user.email, subject: "[brige-crm] ログイン認証コード")
  end
end
