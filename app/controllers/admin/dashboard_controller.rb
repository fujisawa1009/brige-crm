# R0完了条件の検証対象画面（04「ダッシュボード1画面がログイン→OTP→権限チェック→表示を通過」）。
# 全ロールに既定付与される唯一の画面（RoleSeeder::SELF_SERVICE_CONTROLLERS）。
class Admin::DashboardController < Admin::BaseController
  def index
  end
end
