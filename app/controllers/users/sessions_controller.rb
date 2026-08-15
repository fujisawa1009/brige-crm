# パスワード認証成功後、必ずメールOTPの入力待ちへ遷移させる（03§8-2 Q-23=全画面2FA必須。
# ftlogは組織設定otp_required + IP許可リストのAND判定で条件付きスキップしていたが、
# brige-crmは「全画面2要素認証必須」が前提のため、接続元IPがIpAllowlistEntryに一致する場合のみ
# OTPをスキップする（AND条件ではなくOR的赦免。空リストなら誰も赦免されない=フェイルセーフ）。
class Users::SessionsController < Devise::SessionsController
  def create
    # store: false が必須：warden.authenticate! は成功すると内部の set_user 呼び出しで
    # そのままセッションに永続化してしまうため、sign_in を呼ばなくても実質ログイン完了してしまい
    # OTPによる二要素目のゲートが意味を失う（ftlog踏襲のコメント・実測済みの罠）。
    self.resource = warden.authenticate!(auth_options.merge(store: false))

    if IpAllowlistEntry.allows?(request.remote_ip)
      # force: true が必須：直前の warden.authenticate!(store: false) により
      # warden.user(scope) が既に resource を指しているため、force を付けないと
      # 「warden.user(scope) == resource なら何もしない」という短絡分岐に該当し、
      # セッションが一切保存されないままログイン済み扱いの見た目だけになる（ftlog踏襲）。
      set_flash_message!(:notice, :signed_in)
      sign_in(resource, force: true)
      resource.log_login_succeeded!(ip_address: request.remote_ip, request_id: request.request_id)
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      start_otp_challenge(resource)
      redirect_to new_user_otp_path, notice: "認証コードをメールアドレス宛に送信しました。"
    end
  end

  private

  def start_otp_challenge(resource)
    code = resource.generate_otp_code!
    OtpMailer.login_code(resource, code).deliver_later
    session[:otp_user_id] = resource.id
  end
end
