# IP許可リスト管理（04 R0-4・P4-17）。RoleSeederでadmin(super_admin)専有に設定済み
# （実務運用者・代理店系ロールに開放すると自分の接続元IPを登録してOTPを回避できてしまうため）。
class Admin::IpAllowlistEntriesController < Admin::BaseController
  def index
    @entries = IpAllowlistEntry.recent
    @entry = IpAllowlistEntry.new
  end

  def create
    @entry = IpAllowlistEntry.new(entry_params)
    if @entry.save
      redirect_to admin_ip_allowlist_entries_path, notice: "許可リストに追加しました。"
    else
      @entries = IpAllowlistEntry.recent
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    IpAllowlistEntry.find(params[:id]).destroy!
    redirect_to admin_ip_allowlist_entries_path, notice: "許可リストから削除しました。"
  end

  private

  def entry_params
    params.require(:ip_allowlist_entry).permit(:cidr, :note)
  end
end
