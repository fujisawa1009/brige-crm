# Devise/OTPの認証イベント（ログイン成功・失敗・OTP発行/照合・アカウントロック・パスワード再設定）を
# AuditLogに記録する（04 R0-7・R0完了条件「ログイン・権限チェックイベントの監査ログ記録」）。
# ftlogのAuthAuditableから acts_as_tenant 前提（`return unless organization`）を除去した単一テナント版。
module AuthAuditable
  extend ActiveSupport::Concern

  AUTH_ACTIONS = %w[
    login_succeeded
    login_failed
    account_locked
    password_reset_requested
    password_reset_completed
    password_reset_failed
    otp_issued
    otp_verified
    otp_failed
  ].freeze

  # ログイン成功（セッション確立）。Users::SessionsController#create から明示的に呼ぶ
  # （ftlogはWardenフックから呼んでいたが、R0では呼び出し元を明示してシンプルにした）。
  def log_login_succeeded!(ip_address: nil, request_id: nil)
    log_auth_event(:login_succeeded, ip_address: ip_address, request_id: request_id)
  end

  def valid_password?(password)
    result = super
    log_auth_event(:login_failed) unless result
    result
  end

  def lock_access!(opts = {})
    super
    log_auth_event(:account_locked)
  end

  def send_reset_password_instructions
    token = super
    log_auth_event(:password_reset_requested)
    token
  end

  def reset_password(new_password, new_password_confirmation)
    result = super
    log_auth_event(errors.empty? ? :password_reset_completed : :password_reset_failed)
    result
  end

  # OtpAuthenticatable concern のフック（otp_issued / otp_verified / otp_failed）をAuditLogに橋渡しする。
  def after_otp_event(event)
    super
    log_auth_event(event)
  end

  private

  def log_auth_event(action, ip_address: nil, request_id: nil)
    AuditLog.create!(
      user_id:        id,
      user_type:      self.class.name,
      action:         action.to_s,
      resource_type:  "User",
      resource_id:    id,
      resource_label: email,
      ip_address:     ip_address || Current.ip_address,
      source:         "web",
      request_id:     request_id || Current.request_id
    )
  end
end
