class Rack::Attack
  # Solid Cache（Rails.cache）をストアとして使う。追加のインフラ不要（ftlog踏襲）。
  Rack::Attack.cache.store = Rails.cache

  throttle("password_resets/email", limit: 3, period: 15.minutes) do |req|
    if req.path == "/users/password" && req.post?
      email = req.params.dig("user", "email").to_s.downcase.strip
      email.presence
    end
  end

  # ログイン試行の総当たり対策（04 R0追加タスク・release-readiness C-6）。管理画面（Devise User）・
  # 受注入力（代理店CD＋営業CD）・顧客マイページ（Devise Customer）の3系統すべてに、
  # 識別子（メール／代理店CD+営業CD）単位でスロットルする。IPローテーションされても
  # 識別子側で止まる（password_resets/emailと同じ設計）。
  throttle("logins/user_email", limit: 5, period: 15.minutes) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end

  throttle("logins/customer_email", limit: 5, period: 15.minutes) do |req|
    if req.path == "/mypage/login" && req.post?
      req.params.dig("customer", "email").to_s.downcase.strip.presence
    end
  end

  throttle("logins/form_sales_representative", limit: 5, period: 15.minutes) do |req|
    if req.path == "/form/login" && req.post?
      agency_code = req.params["agency_code"].to_s.strip
      sales_rep_code = req.params["sales_rep_code"].to_s.strip
      "#{agency_code}:#{sales_rep_code}".presence if agency_code.present? || sales_rep_code.present?
    end
  end

  # メールOTP（二要素認証）：コード照合・再送信ともIPベースでスロットリングする。
  # コード単位の試行回数（User#otp_attempts等、上限5回）とは別レイヤーの防御。
  # 3系統（管理画面/受注入力/顧客マイページ）すべてに同型で適用する。
  throttle("otp_verify/user_ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.path == "/users/otp" && req.post?
  end

  throttle("otp_resend/user_ip", limit: 3, period: 15.minutes) do |req|
    req.ip if req.path == "/users/otp/resend" && req.post?
  end

  throttle("otp_verify/form_ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.path == "/form/otp" && req.post?
  end

  throttle("otp_resend/form_ip", limit: 3, period: 15.minutes) do |req|
    req.ip if req.path == "/form/otp/resend" && req.post?
  end

  throttle("otp_verify/customer_ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.path == "/mypage/otp" && req.post?
  end

  throttle("otp_resend/customer_ip", limit: 3, period: 15.minutes) do |req|
    req.ip if req.path == "/mypage/otp/resend" && req.post?
  end
end
