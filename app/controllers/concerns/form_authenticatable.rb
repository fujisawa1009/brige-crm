# 受注入力（営業担当者）専用の独自セッション認証（04 R3タスク1・03§8-2認可統合決定(b)）。
#
# SalesRepresentativeはDevise対象外（03§4）でありUser.staff?/customer?のようなSTI判定にも乗らない。
# ApplicationController#skip_system_permission_authorization? がform名前空間の
# authorize_system_permission!を完全スキップする前提のうえで、このconcernだけがform配下を守る
# 「独自FormAuthミドルウェア」に相当する（03§8-2「認可統合」決定の実装）。
#
# セッション確立の2段階（Q-23）:
#   1. Form::SessionsController#create: 代理店CD＋営業担当者CDで本人を特定し、session[:form_otp_sales_representative_id]
#      へ「OTP待ち」を記録してメールOTPを発行する（まだログイン済みにしない）。
#   2. Form::OtpsController#create: OTP照合に成功して初めてsession[:form_sales_representative_id]を立てる
#      （このconcernが認証済みとみなす唯一の条件）。
module FormAuthenticatable
  extend ActiveSupport::Concern

  included do
    # ApplicationControllerのDevise(User)向けauthenticate_user!はform名前空間に適用しない
    # （SalesRepresentativeはUserではないため、そのまま通すとログイン画面へ誤誘導してしまう）。
    skip_before_action :authenticate_user!
    before_action :require_form_sales_representative!
    helper_method :current_sales_representative
  end

  private

  def current_sales_representative
    @current_sales_representative ||=
      SalesRepresentative.active.find_by(id: session[:form_sales_representative_id])
  end

  def require_form_sales_representative!
    return if current_sales_representative

    redirect_to form_new_session_path, alert: "ログインしてください。"
  end
end
