# 顧客マイページログイン 第1段階（04 R4タスク5・Users::SessionsController同型）。
# Q-23（全画面2FA必須）に準拠し、パスワード認証に成功しても必ずメールOTPへ進む。
# ftlog踏襲のUsers::SessionsControllerと異なり、IP許可リストによるOTPスキップは行わない
# （03§8-2 Q-23決定は「マイページ=Devise Customerスコープに同型メールOTPを追加」であり、
# P4-17のIP許可リスト赦免は社内オペレーター向けの仕組みでマイページの想定利用者=社外の顧客には
# そぐわないため、意図的に単純化した。全リクエストで必ずOTPを挟む）。
class Mypage::SessionsController < Devise::SessionsController
  def create
    # store: false の理由はUsers::SessionsControllerのコメント参照（warden.authenticate!が
    # 内部でセッションを永続化してしまいOTPゲートを迂回する罠の回避）。
    self.resource = warden.authenticate!(auth_options.merge(store: false))

    start_otp_challenge(resource)
    redirect_to new_customer_otp_path, notice: "認証コードをメールアドレス宛に送信しました。"
  end

  private

  def start_otp_challenge(resource)
    code = resource.generate_otp_code!
    OtpMailer.mypage_login_code(resource, code).deliver_later
    session[:customer_otp_customer_id] = resource.id
  end
end
