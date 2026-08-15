# メールOTP入力（ftlog踏襲）。ログイン成功の監査ログ記録（AuthAuditable#log_login_succeeded!）は
# ここ（OTP照合成功時）で行う。IP許可リストによりOTPをスキップした場合は
# Users::SessionsController#create 側で直接記録する。
class Users::OtpsController < DeviseController
  prepend_before_action :require_otp_pending_user!

  def new
  end

  def create
    case pending_user.verify_otp_code(params[:code])
    when :success
      complete_sign_in!
    when :incorrect
      flash.now[:alert] = "コードが正しくありません。"
      render :new, status: :unprocessable_entity
    when :expired
      flash.now[:alert] = "コードの有効期限が切れています。再送信してください。"
      render :new, status: :unprocessable_entity
    when :locked
      reset_otp_session
      redirect_to new_user_session_path, alert: "試行回数の上限に達しました。お手数ですが再度ログインしてください。"
    end
  end

  def resend
    code = pending_user.generate_otp_code!
    OtpMailer.login_code(pending_user, code).deliver_later
    redirect_to new_user_otp_path, notice: "コードを再送信しました。"
  end

  private

  def pending_user
    @pending_user ||= User.find_by(id: session[:otp_user_id])
  end

  def require_otp_pending_user!
    return if pending_user

    redirect_to new_user_session_path, alert: "セッションが切れました。再度ログインしてください。"
  end

  def complete_sign_in!
    sign_in(pending_user)
    pending_user.log_login_succeeded!(ip_address: request.remote_ip, request_id: request.request_id)
    reset_otp_session
    redirect_to after_sign_in_path_for(pending_user), notice: "ログインしました。"
  end

  def reset_otp_session
    session.delete(:otp_user_id)
  end
end
