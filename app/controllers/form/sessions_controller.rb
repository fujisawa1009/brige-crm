# 受注入力ログイン 第1段階（04 R3タスク1）。認証キー=代理店CD＋営業担当者CD（Laravel現行
# SalesForm/AuthController踏襲。01§4「受注入力: Laravelガード不使用。セッション＋独自ミドルウェア」）。
# ここではまだセッションを確立しない（03§8-2 Q-23: 必ずメールOTPを挟む。完了はForm::OtpsController）。
#
# IP許可リストによるOTP免除（CEO判断）: Users::SessionsController と同じ判定
# （IpAllowlistEntry.allows?(request.remote_ip)）をここにも適用する。admin画面だけOTPを免除できて
# form画面はできない、という非対称を解消するため。IpAllowlistEntryは空リスト時に必ずfalseを返す
# フェイルセーフ設計（app/models/ip_allowlist_entry.rb参照）なので、未設定なら従来どおり全員OTP必須。
class Form::SessionsController < Form::BaseController
  skip_before_action :require_form_sales_representative!

  def new
  end

  def create
    sales_representative = find_sales_representative

    if sales_representative.nil?
      flash.now[:alert] = "代理店CDまたは営業担当者CDが正しくありません。"
      render :new, status: :unprocessable_entity
    elsif IpAllowlistEntry.allows?(request.remote_ip)
      complete_sign_in!(sales_representative)
    elsif sales_representative.email.blank?
      # OTP送信先が無いと二要素目に進めない（Q-23は全画面必須のため、メール未設定は運用不備として
      # 明示的にエラーにする。過去に無かった状態を想定した運用ガード）。
      flash.now[:alert] = "営業担当者にメールアドレスが未設定のためログインできません。管理者にご連絡ください。"
      render :new, status: :unprocessable_entity
    else
      start_otp_challenge(sales_representative)
      redirect_to form_new_otp_path, notice: "認証コードをメールアドレス宛に送信しました。"
    end
  end

  def destroy
    reset_session
    redirect_to form_new_session_path, notice: "ログアウトしました。"
  end

  private

  def find_sales_representative
    agency = Agency.find_by(agency_code: params[:agency_code])
    agency&.sales_representatives&.active&.find_by(sales_rep_code: params[:sales_rep_code])
  end

  # Form::OtpsController#complete_sign_in! と同じくsession[:form_sales_representative_id]を
  # 直接立てる（SalesRepresentativeはDevise対象外・FormAuthenticatable concern参照）。
  def complete_sign_in!(sales_representative)
    session[:form_sales_representative_id] = sales_representative.id
    redirect_to form_new_application_path, notice: "ログインしました。"
  end

  def start_otp_challenge(sales_representative)
    code = sales_representative.generate_otp_code!
    OtpMailer.form_login_code(sales_representative, code).deliver_later
    session[:form_otp_sales_representative_id] = sales_representative.id
  end
end
