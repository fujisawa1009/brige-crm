require "rails_helper"

# OtpAuthenticatable concern（04 R0-4。User専用実装ではなく再利用可能なconcernとして切り出した設計）の
# 挙動確認。将来のCustomer/SalesRepresentativeでも同じ振る舞いになることをUser経由で担保する。
RSpec.describe User, type: :model do
  let(:user) { create(:user) }

  describe "#generate_otp_code! / #verify_otp_code" do
    it "生成したコードで照合すると成功し、以降は再利用できない" do
      code = user.generate_otp_code!
      expect(user.verify_otp_code(code)).to eq(:success)
      expect(user.verify_otp_code(code)).to eq(:expired) # clear_otp_code!済みでdigestがnilになる
    end

    it "誤ったコードはincorrectを返し、試行回数を消費する" do
      user.generate_otp_code!
      expect(user.verify_otp_code("000000")).to eq(:incorrect)
      expect(user.reload.otp_attempts).to eq(1)
    end

    it "試行回数の上限に達するとlockedを返す" do
      user.generate_otp_code!
      4.times { user.verify_otp_code("000000") }
      expect(user.verify_otp_code("000000")).to eq(:locked)
    end

    it "有効期限切れのコードはexpiredを返す" do
      user.generate_otp_code!
      user.update_columns(otp_code_expires_at: 1.minute.ago)
      expect(user.verify_otp_code(user.otp_code_digest)).to eq(:expired)
    end
  end

  describe "監査ログ連携（AuthAuditable#after_otp_event）" do
    it "OTP発行・照合成功のイベントがAuditLogに記録される" do
      code = user.generate_otp_code!
      user.verify_otp_code(code)

      actions = AuditLog.where(user_id: user.id).pluck(:action)
      expect(actions).to include("otp_issued", "otp_verified")
    end
  end
end
