# 顧客マイページログイン 第2段階・メールOTP照合（04 R4タスク5・Users::OtpsController同型）。
class Mypage::OtpsController < DeviseController
  prepend_before_action :require_otp_pending_customer!

  def new
  end

  def create
    case pending_customer.verify_otp_code(params[:code])
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
      redirect_to new_customer_session_path, alert: "試行回数の上限に達しました。お手数ですが再度ログインしてください。"
    end
  end

  def resend
    code = pending_customer.generate_otp_code!
    OtpMailer.mypage_login_code(pending_customer, code).deliver_later
    redirect_to new_customer_otp_path, notice: "コードを再送信しました。"
  end

  private

  def pending_customer
    @pending_customer ||= Customer.find_by(id: session[:customer_otp_customer_id])
  end

  def require_otp_pending_customer!
    return if pending_customer

    redirect_to new_customer_session_path, alert: "セッションが切れました。再度ログインしてください。"
  end

  def complete_sign_in!
    sign_in(pending_customer)
    pending_customer.log_login_succeeded!(ip_address: request.remote_ip, request_id: request.request_id)
    reset_otp_session
    redirect_to mypage_dashboard_path, notice: "ログインしました。"
  end

  def reset_otp_session
    session.delete(:customer_otp_customer_id)
  end
end
