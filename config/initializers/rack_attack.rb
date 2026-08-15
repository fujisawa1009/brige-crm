class Rack::Attack
  # Solid Cache（Rails.cache）をストアとして使う。追加のインフラ不要（ftlog踏襲）。
  Rack::Attack.cache.store = Rails.cache

  throttle("password_resets/email", limit: 3, period: 15.minutes) do |req|
    if req.path == "/users/password" && req.post?
      email = req.params.dig("user", "email").to_s.downcase.strip
      email.presence
    end
  end

  # メールOTP（二要素認証）：コード照合・再送信ともIPベースでスロットリングする。
  # コード単位の試行回数（User#otp_attempts, 上限5回）とは別レイヤーの防御。
  throttle("otp_verify/ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.path == "/users/otp" && req.post?
  end

  throttle("otp_resend/ip", limit: 3, period: 15.minutes) do |req|
    req.ip if req.path == "/users/otp/resend" && req.post?
  end
end
