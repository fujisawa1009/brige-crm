# admin/login_histories のイベント種別表示（日本語ラベル・バッジ配色）。
module Admin::LoginHistoriesHelper
  EVENT_LABELS = {
    "login_succeeded"           => "ログイン成功",
    "login_failed"              => "ログイン失敗",
    "account_locked"            => "アカウントロック",
    "password_reset_requested"  => "パスワード再設定リクエスト",
    "password_reset_completed"  => "パスワード再設定完了",
    "password_reset_failed"     => "パスワード再設定失敗",
    "otp_issued"                => "OTP発行",
    "otp_verified"              => "OTP認証成功",
    "otp_failed"                => "OTP認証失敗",
    "permission_denied"         => "権限拒否"
  }.freeze

  FAILURE_EVENTS = %w[login_failed account_locked password_reset_failed otp_failed permission_denied].freeze
  SUCCESS_EVENTS = %w[login_succeeded password_reset_completed otp_verified].freeze

  def auth_event_label(action)
    EVENT_LABELS.fetch(action, action)
  end

  def auth_event_badge(action)
    color =
      if FAILURE_EVENTS.include?(action)
        "red"
      elsif SUCCESS_EVENTS.include?(action)
        "green"
      else
        "slate"
      end

    badge_tag(auth_event_label(action), color: color)
  end
end
