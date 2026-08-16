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

  it "billing_password等のPII暗号化対象カラムはCSVの列に含まれない（Orderの場合）" do
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
end
