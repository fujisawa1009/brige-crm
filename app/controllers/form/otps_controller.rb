# 受注入力ログイン 第2段階・メールOTP照合（04 R3タスク2・03§8-2 Q-23）。
# ftlog踏襲のUsers::OtpsController（app/controllers/users/otps_controller.rb）と同型だが、
# Deviseのsign_inを使わずsession[:form_sales_representative_id]を直接立てる点が異なる
# （SalesRepresentativeはDevise対象外・FormAuthenticatable concern参照）。
class Form::OtpsController < Form::BaseController
  skip_before_action :require_form_sales_representative!
  prepend_before_action :require_otp_pending_sales_representative!

  def new
  end

  def create
    case pending_sales_representative.verify_otp_code(params[:code])
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
      redirect_to form_new_session_path, alert: "試行回数の上限に達しました。お手数ですが再度ログインしてください。"
    end
  end

  def resend
    code = pending_sales_representative.generate_otp_code!
    OtpMailer.form_login_code(pending_sales_representative, code).deliver_later
    redirect_to form_new_otp_path, notice: "コードを再送信しました。"
  end

  private

  def pending_sales_representative
    @pending_sales_representative ||=
      SalesRepresentative.find_by(id: session[:form_otp_sales_representative_id])
  end

  def require_otp_pending_sales_representative!
    return if pending_sales_representative

    redirect_to form_new_session_path, alert: "セッションが切れました。再度ログインしてください。"
  end

  def complete_sign_in!
    session[:form_sales_representative_id] = pending_sales_representative.id
    reset_otp_session
    redirect_to form_new_application_path, notice: "ログインしました。"
  end

  def reset_otp_session
    session.delete(:form_otp_sales_representative_id)
  end
end
