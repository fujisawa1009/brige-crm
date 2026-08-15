# メールOTPによる二要素認証（04 R0-4 / 03§8-2 Q-23）。
#
# ftlogのUser#generate_otp_code!/verify_otp_code!はUser専用の実装だったが、brige-crmは
# 「全画面2要素認証必須」（Q-23・D-5）のためUser（管理画面）だけでなくR3のSalesRepresentative
# （受注入力の独自セッション）・R4のCustomer（マイページ）からも同じロジックを呼べる必要がある。
# そのためモデル横断で再利用できるconcernとして切り出す（User専用実装のままだと横展開時に
# コピペ複製かサービス化のやり直しが発生するため、R0の時点で再利用可能な形にしておく）。
#
# 前提: includeするモデルは以下のカラムを持つこと（DeviseCreateUsersマイグレーション参照）。
#   otp_code_digest:string / otp_code_expires_at:datetime / otp_attempts:integer(default 0)
#
# 監査ログ記録はホスト側の責務に委ねる（Userは AuthAuditable#log_auth_event を otp_issued 等の
# タイミングで呼ぶ）。このconcernは「監査すべきイベントが起きたこと」を知らせるために
# after_otp_event フックメソッド（デフォルトは何もしない）を用意し、ホスト側でオーバーライドする。
module OtpAuthenticatable
  extend ActiveSupport::Concern

  included do
    OTP_CODE_LENGTH  = 6
    OTP_VALID_FOR    = 10.minutes
    OTP_MAX_ATTEMPTS = 5
  end

  # ログイン用ワンタイムコードを発行し、DBにはハッシュのみ保存する。平文コードは
  # メール送信用に戻り値として返すのみでモデルには残さない（ftlog踏襲）。
  def generate_otp_code!
    code = format("%0#{self.class::OTP_CODE_LENGTH}d", SecureRandom.random_number(10**self.class::OTP_CODE_LENGTH))
    update_columns(
      otp_code_digest:     Digest::SHA256.hexdigest(code),
      otp_code_expires_at: self.class::OTP_VALID_FOR.from_now,
      otp_attempts:        0
    )
    after_otp_event(:otp_issued)
    code
  end

  # :success / :incorrect / :expired / :locked のいずれかを返す。
  def verify_otp_code(input)
    return :expired if otp_code_digest.blank? || otp_code_expires_at.nil? || otp_code_expires_at < Time.current
    return :locked   if otp_attempts.to_i >= self.class::OTP_MAX_ATTEMPTS

    if ActiveSupport::SecurityUtils.secure_compare(otp_code_digest, Digest::SHA256.hexdigest(input.to_s))
      clear_otp_code!
      after_otp_event(:otp_verified)
      :success
    else
      increment!(:otp_attempts)
      after_otp_event(:otp_failed)
      otp_attempts >= self.class::OTP_MAX_ATTEMPTS ? :locked : :incorrect
    end
  end

  def clear_otp_code!
    update_columns(otp_code_digest: nil, otp_code_expires_at: nil, otp_attempts: 0)
  end

  private

  # ホスト側（User等）でオーバーライドして監査ログ等に接続する。既定は無処理。
  def after_otp_event(event)
  end
end
