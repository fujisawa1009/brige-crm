require "rails_helper"

# 04 R0追加タスク・release-readiness C-6: rack-attackのログイン試行制限を
# 管理画面（/users/sign_in）・受注入力（/form/login）・顧客マイページ（/mypage/login）の
# 3系統すべてに適用したことを検証する（従来は/users/password・/users/otp*のみが対象だった）。
#
# rack-attackはSolid Cache（Rails.cache）をストアにしているが、test環境の既定は
# config.cache_store = :null_store のため通常はスロットルが効かない（rails_helper参照）。
# ここでは各exampleの間だけ実キャッシュに差し替えて検証する。
RSpec.describe "Rack::Attack ログイン試行制限", type: :request do
  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.cache.store = original_store
  end

  describe "/users/sign_in（管理画面）" do
    let!(:user) { create(:user, password: "Password1234", password_confirmation: "Password1234") }

    it "同一メールで6回目のログイン試行は429になる" do
      5.times do
        post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }
      end
      post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "/mypage/login（顧客マイページ）" do
    let!(:customer) do
      create(:customer, email: "customer@example.com", password: "Password1234", password_confirmation: "Password1234")
    end

    it "同一メールで6回目のログイン試行は429になる" do
      5.times do
        post customer_session_path, params: { customer: { email: customer.email, password: "wrong-password" } }
      end
      post customer_session_path, params: { customer: { email: customer.email, password: "wrong-password" } }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "/form/login（受注入力）" do
    let!(:agency) { create(:agency) }
    let!(:sales_representative) { create(:sales_representative, agency: agency) }

    it "同一の代理店CD・営業担当者CDで6回目のログイン試行は429になる" do
      5.times do
        post form_sessions_path, params: { agency_code: agency.agency_code, sales_rep_code: "WRONG-CODE" }
      end
      post form_sessions_path, params: { agency_code: agency.agency_code, sales_rep_code: "WRONG-CODE" }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "/form/otp（受注入力OTP照合）" do
    let!(:agency) { create(:agency) }
    let!(:sales_representative) { create(:sales_representative, agency: agency, email: "rep@example.com") }

    it "同一IPから11回目のOTP照合試行は429になる" do
      post form_sessions_path, params: { agency_code: agency.agency_code, sales_rep_code: sales_representative.sales_rep_code }

      10.times { post form_otp_path, params: { code: "000000" } }
      post form_otp_path, params: { code: "000000" }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "/mypage/otp（顧客マイページOTP照合）" do
    let!(:customer) do
      create(:customer, email: "customer2@example.com", password: "Password1234", password_confirmation: "Password1234")
    end

    it "同一IPから11回目のOTP照合試行は429になる" do
      post customer_session_path, params: { customer: { email: customer.email, password: "Password1234" } }

      10.times { post customer_otp_path, params: { code: "000000" } }
      post customer_otp_path, params: { code: "000000" }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
