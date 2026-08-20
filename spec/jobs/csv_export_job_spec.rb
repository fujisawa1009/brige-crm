require "rails_helper"

# 04 R2タスク7: CsvExportJobがPundit policy_scopeを通してからCSV化することを検証する
# （代理店ユーザーのエクスポートに他代理店のCustomerが混入しないこと＝一覧のスコープ漏れ防止と同じ担保）。
# RBACカタログ同期(SystemPermissionSyncService)は不要（CsvExportJobはPunditのpolicy_scopeのみ通す
# ため）。RoleSeeder.callだけで組み込みロール（代理店用）を用意する
# （seed_permission_catalog!ヘルパーはtype: :request専用のためtype: :jobでは使えない）。
RSpec.describe CsvExportJob, type: :job, seed_status_catalog: true do
  before { RoleSeeder.call }

  let!(:agency_a) { create(:agency) }
  let!(:agency_b) { create(:agency) }
  let!(:customer_a) { create(:customer, agency: agency_a, name: "顧客A") }
  let!(:customer_b) { create(:customer, agency: agency_b, name: "顧客B") }
  let!(:agency_user) do
    role = SystemRole.find_by!(name: "代理店用")
    user = create(:user, agency: agency_a)
    UserSystemRole.create!(user: user, system_role: role)
    user
  end

  it "代理店ユーザーがリクエストしたCustomerエクスポートには自代理店の顧客のみ含まれる" do
    export = CsvExport.create!(resource_type: "Customer", requested_by: agency_user, status: "pending")

    described_class.perform_now(export.id)
    export.reload

    expect(export.status).to eq("completed")
    expect(export.file_data).to include(customer_a.customer_number)
    expect(export.file_data).not_to include(customer_b.customer_number)
    expect(export.row_count).to eq(1)
  end

  # Q-45（2026-08-19）で暗号化を全廃したため、秘匿値の除外はEXPORT_TARGETSの許可リストのみが担保する。
  it "billing_password等の秘匿値カラムはCSVの列に含まれない（Orderの場合）" do
    contract_condition = create(:contract_condition, agency: agency_a)
    create(:order, agency: agency_a, customer: customer_a, contract_condition: contract_condition,
                   billing_password: "secret-pass")
    export = CsvExport.create!(resource_type: "Order", requested_by: agency_user, status: "pending")

    described_class.perform_now(export.id)
    export.reload

    expect(export.file_data).not_to include("secret-pass")
    expect(export.file_data).not_to include("billing_password")
  end

  it "代理店ユーザーがリクエストしたOrderエクスポートには自代理店の案件のみ含まれる" do
    contract_condition_a = create(:contract_condition, agency: agency_a)
    contract_condition_b = create(:contract_condition, agency: agency_b)
    order_a = create(:order, agency: agency_a, customer: customer_a, contract_condition: contract_condition_a)
    order_b = create(:order, agency: agency_b, customer: customer_b, contract_condition: contract_condition_b)
    export = CsvExport.create!(resource_type: "Order", requested_by: agency_user, status: "pending")

    described_class.perform_now(export.id)
    export.reload

    expect(export.status).to eq("completed")
    expect(export.file_data).to include(order_a.order_number)
    expect(export.file_data).not_to include(order_b.order_number)
    expect(export.row_count).to eq(1)
  end

  # CEO報告 2026-08-20:「顧客一覧のCSVエクスポートでダウンロードすると文字化けしている」。
  # 原因はBOMなしUTF-8を日本語版WindowsのExcelがCP932と誤認して開くこと。
  # CEO決定により既定の出力を UTF-8 + BOM へ変更した（export-profile-design.md §3・§172 の未決事項を確定）。
  describe "文字コード（UTF-8 BOM。CEO決定 2026-08-20）" do
    let!(:export) { CsvExport.create!(resource_type: "Customer", requested_by: agency_user, status: "pending") }

    it "出力の先頭にUTF-8のBOMが付く" do
      described_class.perform_now(export.id)

      # 実際にファイルへ書き出されるバイト列で確認する（\uFEFF との比較だと、UTF-8として
      # 正しい3バイトになっているかまでは分からないため）。
      expect(export.reload.file_data.b).to start_with("\xEF\xBB\xBF".b)
    end

    it "BOMを除いた本体は従来どおり（ヘッダ行＋データ行のUTF-8 CSV）で変わらない" do
      described_class.perform_now(export.id)

      body = export.reload.file_data.delete_prefix(described_class::BOM)
      expect(body.lines.first.chomp).to eq(described_class::EXPORT_TARGETS["Customer"][:columns].join(","))
      expect(body).not_to include(described_class::BOM)
      expect(body.encoding).to eq(Encoding::UTF_8)
    end

    it "CP932に無い文字を含む日本語データもそのまま往復する" do
      # ①・髙・〜 は CP932 へ変換できない/化けやすい代表例。CP932変換ではなくBOM付与を選んだ理由。
      customer_a.update!(name: "株式会社髙島①〜テスト")

      described_class.perform_now(export.id)

      rows = CSV.parse(export.reload.file_data.delete_prefix(described_class::BOM), headers: true)
      expect(rows.map { |r| r["name"] }).to include("株式会社髙島①〜テスト")
    end
  end
end
