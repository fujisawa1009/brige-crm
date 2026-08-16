require "rails_helper"

# R1修正: CSV.parse自体（ヘッダー行を含むCSV全体の構文）が失敗した場合、従来は行単位の
# import_row内rescueでは捕捉できず例外がジョブから素通しで上がっていた（ジョブが失敗扱いになる
# だけで管理者からは何が起きたか見えない）。CSV::MalformedCSVError等を明示的にrescueし、
# Rails.loggerに記録した上でResult(created: 0, failed: [])を返すことを検証する
# （既存のResult構造体・戻り値の型は変えない＝呼び出し側との互換性を保つ）。
RSpec.describe UserCsvImportJob, type: :job do
  let!(:admin_user) { create(:user) }

  it "ヘッダー行の引用符が閉じていない壊れたCSVでも例外を外に漏らさずログに記録し、Result(created: 0, failed: [])を返す" do
    broken_csv = %(name,email,"password\nユーザー1,broken@example.com,x\n)

    result = nil
    expect(Rails.logger).to receive(:error).with(a_string_including("UserCsvImportJob", "CSVファイル全体のパースに失敗"))

    expect {
      result = described_class.perform_now(broken_csv, requested_by_user_id: admin_user.id)
    }.not_to raise_error

    expect(result.created).to eq(0)
    expect(result.failed).to eq([])
    expect(User.exists?(email: "broken@example.com")).to eq(false)
  end

  it "正常なCSVは従来通り行ごとにUserを作成する" do
    csv = "name,email,password,is_active\n正常ユーザー,normal-import@example.com,Password1234,true\n"

    result = described_class.perform_now(csv, requested_by_user_id: admin_user.id)

    expect(result.created).to eq(1)
    expect(result.failed).to eq([])
    expect(User.exists?(email: "normal-import@example.com")).to eq(true)
  end
end
