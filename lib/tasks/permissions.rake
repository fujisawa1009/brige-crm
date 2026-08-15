# 権限カタログ同期・既定ロールseed（04 R0-5・R0-9）。ftlogのlib/tasks/permissions.rakeを移植。
namespace :permissions do
  desc "ルート定義からSystemPermissionカタログを同期する（起動時に自動実行。db/seedsからも呼ばれる）"
  task sync: :environment do
    result = SystemPermissionSyncService.call
    puts "SystemPermission synced: created=#{result.created} updated=#{result.updated} disabled=#{result.disabled} active=#{result.active}"
  end

  desc "組み込みロールへ既定の権限マトリクスを付与する（追加のみ・冪等）"
  task seed_roles: :environment do
    RoleSeeder.call
    puts "RoleSeeder done: #{SystemRole.pluck(:name).join(', ')}"
  end
end
