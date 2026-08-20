require "rails_helper"

# CSVエクスポート成果物のダウンロード（Admin::CsvExportsController#show）。
#
# CEO報告 2026-08-20:「顧客一覧のCSVエクスポートでダウンロードすると文字化けしている」。
# 生成側（CsvExportJob）が UTF-8 BOM を付ける方針に変えたので、ダウンロード経路でも
# ①BOMが欠けたり二重に付いたりしないこと ②Content-Type に charset が入ること を押さえる。
# 生成側そのものの検証は spec/jobs/csv_export_job_spec.rb。
RSpec.describe "Admin::CsvExports ダウンロード", type: :request,
                                                 seed_permission_catalog: true,
                                                 seed_status_catalog: true,
                                                 system_authorization: true do
  let!(:admin_user) { user_with_role("admin") }

  before { sign_in_with_otp!(admin_user) }

  it "UTF-8 BOM 付きで配信され、Content-Type に charset=utf-8 が入る（Excelでの文字化け対策）" do
    create(:customer, name: "株式会社髙島①〜テスト")
    export = CsvExport.create!(resource_type: "Customer", requested_by: admin_user, status: "pending")
    CsvExportJob.perform_now(export.id)

    get admin_csv_export_path(export)

    expect(response).to have_http_status(:ok)
    expect(response.body.b).to start_with("\xEF\xBB\xBF".b)
    # 生成時に1回だけ付ける設計。コントローラ側でも足すと BOM が2つ並んで逆に壊れる。
    expect(response.body.b.scan("\xEF\xBB\xBF".b).size).to eq(1)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Type"]).to include("charset=utf-8")
    expect(response.body).to include("株式会社髙島①〜テスト")
  end
end
