# CSVエクスポート成果物の一覧・ダウンロード（04 R2タスク7）。生成のトリガーは各リソース
# コントローラー（例: Admin::CustomersController#export）が担い、ここは結果の受け皿に徹する。
class Admin::CsvExportsController < Admin::BaseController
  def index
    # ページネーション追加（CEO指示 2026-08-20 タスク6）。エクスポート履歴は使うほど
    # 単調に増える一方で消えないため、全件描画のままでは行数が青天井になる。
    @pagy, @csv_exports = pagy(policy_scope(CsvExport).order(created_at: :desc, id: :asc))
  end

  def show
    export = CsvExport.find(params[:id])
    authorize export

    if export.status != "completed"
      redirect_to admin_csv_exports_path, alert: "エクスポートはまだ完了していません（状態: #{export.status}）。"
      return
    end

    send_data export.file_data,
              filename: "#{export.resource_type.underscore}_#{export.id}.csv",
              type: "text/csv"
  end
end
