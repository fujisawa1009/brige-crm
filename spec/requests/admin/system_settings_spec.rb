require "rails_helper"

# R6-3: システム設定画面。ip_allowlist_entries/permission_management等と同じ
# 「テナントスコープを持たない、RBACのみで守られるadmin(super_admin)専有画面」であることと、
# 表示・更新の基本動作を検証する。
RSpec.describe "Admin::SystemSettings", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:admin_user) { user_with_role("admin") }

  describe "未ログイン" do
    it "ログイン画面へリダイレクトされる" do
      get admin_system_settings_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "adminとしてログイン中" do
    before { sign_in_with_otp!(admin_user) }

    it "システム設定画面を表示できる（verify_authorized/verify_policy_scopedで落ちない）" do
      get admin_system_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("システム設定")
    end

    it "初回表示時にSystemSettingが既定値で1件作成される" do
      expect { get admin_system_settings_path }.to change(SystemSetting, :count).from(0).to(1)
    end

    it "添付上限を更新できる" do
      patch admin_system_settings_path, params: {
        system_setting: { inquiry_attachment_max_count: 3, inquiry_attachment_max_size_mb: 20 }
      }

      expect(response).to redirect_to(admin_system_settings_path)
      setting = SystemSetting.current
      expect(setting.inquiry_attachment_max_count).to eq(3)
      expect(setting.inquiry_attachment_max_size_mb).to eq(20)
    end

    it "不正な値（0以下）を送るとエラーで再表示され、値は更新されない" do
      SystemSetting.current # 既定値で1件作成しておく

      patch admin_system_settings_path, params: {
        system_setting: { inquiry_attachment_max_count: 0, inquiry_attachment_max_size_mb: 50 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(SystemSetting.current.inquiry_attachment_max_count).to eq(5)
    end
  end

  describe "admin以外はRBACで拒否される（system_admin専有）" do
    %w[実務運用者 代理店グループ用 代理店用].each do |role_name|
      it "#{role_name}ロールは表示できない（403）" do
        agency = create(:agency)
        user =
          case role_name
          when "代理店用" then user_with_role(role_name, agency: agency)
          when "代理店グループ用" then user_with_role(role_name, agency_group: agency.agency_group)
          else user_with_role(role_name)
          end

        sign_in_with_otp!(user)
        get admin_system_settings_path

        expect(response).to have_http_status(:forbidden)
      end

      it "#{role_name}ロールは更新できない（403）" do
        agency = create(:agency)
        user =
          case role_name
          when "代理店用" then user_with_role(role_name, agency: agency)
          when "代理店グループ用" then user_with_role(role_name, agency_group: agency.agency_group)
          else user_with_role(role_name)
          end

        sign_in_with_otp!(user)
        patch admin_system_settings_path, params: {
          system_setting: { inquiry_attachment_max_count: 1, inquiry_attachment_max_size_mb: 1 }
        }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
