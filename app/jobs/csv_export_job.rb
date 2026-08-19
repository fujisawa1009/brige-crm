require "csv"

# CSV非同期エクスポート（04 R2タスク7。UserCsvImportJobと対になる基盤）。
#
# 重要: 単純に「全件ダンプ」すると代理店ユーザーが自分の見えない範囲のデータをCSV経由で
# 抜き取れてしまい、Pundit policy_scope（04 R2完了条件の中核）を丸ごと迂回する穴になる。
# そのため、リクエストしたユーザーに対して Pundit.policy_scope! を通した結果だけをCSV化する
# （画面の一覧と同じ絞り込みが適用される）。
class CsvExportJob < ApplicationJob
  queue_as :default

  # billing_password 等の秘匿値（PII分類B）はCSVへは絶対に出さない
  # （Auditableの「秘匿値は絶対に含めない」原則をエクスポートでも踏襲）。
  # 2026-08-19 CEO決定（Q-45）で ActiveRecord::Encryption を全廃し平文保存へ変更したため、
  # 「暗号化列だから自動的に安全」という前提は無くなった。以下の columns 許可リストが
  # 唯一の防御線になるので、列を追加する際は秘匿値を含めていないか必ず確認すること。
  #
  # クラスは文字列からconstantizeせず、この固定Hashのキーで引く（brakeman UnsafeReflection対策。
  # CsvExport#resource_typeはモデルのinclusion validationで許可リストを持つが、
  # update_column等でバリデーションを迂回された場合の防御を欠かないよう、ジョブ側でも
  # 「DBの文字列を任意クラス名として実行しない」設計にしておく）。
  EXPORT_TARGETS = {
    "Customer" => {
      klass: Customer,
      columns: %w[customer_number name agency_id sales_representative_id status applied_at contracted_at
                  email phone prefecture city town created_at]
    },
    "Order" => {
      klass: Order,
      columns: %w[order_number customer_id store_id agency_id contract_condition_id plan_id status
                  contract_status ordered_at contract_start_date work_completed_at terminated_at created_at]
    }
  }.freeze

  def perform(csv_export_id)
    export = CsvExport.find(csv_export_id)
    user   = export.requested_by
    Current.user = user

    target  = EXPORT_TARGETS.fetch(export.resource_type)
    scope   = Pundit.policy_scope!(user, target[:klass])
    columns = target[:columns]

    csv = CSV.generate(headers: true) do |rows|
      rows << columns
      scope.find_each { |record| rows << columns.map { |c| record.public_send(c) } }
    end

    export.update!(status: "completed", file_data: csv, row_count: scope.count)
  rescue StandardError => e
    export&.update!(status: "failed", error_message: e.message)
    raise
  ensure
    Current.user = nil
  end
end
