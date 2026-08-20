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
  #
  # columns は「カラム名 => CSVの見出し（1行目）」の順序付きHash。**見出しの定義はここが唯一の出所**
  # （CEO決定 2026-08-20「CSVの見出し（1行目）を日本語にして。全てのCSVエクスポートで同様」）。
  # 画面ラベル側とエクスポート側に見出しが二重に散ると、片方だけ巻き戻る事故が起きるため増やさないこと。
  #
  # 見出しの決め方（2026-08-20）:
  #   1. 旧ジャスミンの案件CSV（CP932・日本語ヘッダ238列。`legacy-research/00-index.md` 項番10 /
  #      `11-order-field-mapping.md` §6-2・付録A）で文言が特定できる列は、**旧の文言に合わせる**。
  #      現場が見慣れた語のほうが移行時の混乱が少ないため。
  #   2. 特定できない列（UUIDのFK列・作成日時など旧CSVに対応列が無いもの）は画面ラベルに合わせて命名する。
  #   3. **ステータス系は必ず修飾付き**（`status-naming-analysis.md` §0-0 の適用ルール表
  #      「CSVエクスポートのヘッダ = 修飾付きを維持」）。CSVは顧客と案件の情報が同一ファイルに
  #      混在しうるため、単なる「ステータス」にはしない。
  #      なお旧CSVは `orders.status` を「顧客ステータス」と呼ぶ（付録A 59）が、これは D-8 の使用禁止語
  #      （旧＝案件35値／新＝申込8値で全くの別物を指してしまう）なので**ここでは旧に合わせない**。
  #
  # 列の構成・順序は変更しないこと（今回は見出し文言のみの変更。列構成の旧準拠化は Q-15＝
  # アシスト納品用プロファイルの範囲で、`export-profile-design.md` §5 Step 1/7 が扱う）。
  EXPORT_TARGETS = {
    "Customer" => {
      klass: Customer,
      columns: {
        "customer_number" => "顧客番号",                    # 旧準拠（付録A 1）
        "name" => "契約者名または法人名",                    # 旧準拠（付録A 3）
        "agency_id" => "代理店ID",                          # 新規（旧は販売店CD/名。ここはUUID）
        "sales_representative_id" => "担当営業担当者ID",      # 新規（旧は営業担当者コード/名。ここはUUID）
        "status" => "申込ステータス",                        # 新規・修飾付き（customer_statuses の8値）
        "applied_at" => "お申込日",                          # 新規（画面ラベル準拠）
        "contracted_at" => "契約日",                         # 新規（画面ラベル準拠）
        "email" => "管理者メールアドレス",                    # 旧準拠（付録A 78）
        "phone" => "連絡先固定電話番号",                      # 旧準拠（付録A 83）
        "prefecture" => "都道府県",                          # 新規（旧98「契約者住所」は分割前の1列）
        "city" => "市区郡",                                  # 新規（画面ラベル準拠）
        "town" => "町名",                                    # 新規（画面ラベル準拠）
        "created_at" => "作成日時"                           # 新規（旧CSVに対応列なし）
      }
    },
    "Order" => {
      klass: Order,
      columns: {
        "order_number" => "案件番号",                        # 旧準拠（付録A 2）
        "customer_id" => "顧客ID",                           # 新規（旧1は「顧客番号」。ここはUUID）
        "store_id" => "店舗ID",                              # 新規（UUID）
        "agency_id" => "代理店ID",                           # 新規（UUID）
        "contract_condition_id" => "契約条件ID",              # 新規（UUID）
        "plan_id" => "プランID",                             # 新規（旧60は「プラン名」。ここはUUID）
        "status" => "案件ステータス",                         # 新規・修飾付き（旧59「顧客ステータス」は不採用）
        "contract_status" => "契約ステータス",                # 新規・修飾付き
        "ordered_at" => "受注日",                            # 旧準拠（付録A 33「受注日（申込日）」の基本語）
        "contract_start_date" => "契約開始日",                # 旧準拠（付録A 36）
        "work_completed_at" => "作業完了日",                  # 旧準拠（付録A 40「作業完了日（納品完了メール送付日）」の基本語）
        "terminated_at" => "解約日",                          # 旧準拠（付録A 57）
        "created_at" => "作成日時"                            # 新規（旧CSVに対応列なし）
      }
    }
  }.freeze

  # 出力の先頭に付けるUTF-8のBOM（CEO決定 2026-08-20。export-profile-design.md §3・§172 の未決事項を確定）。
  #
  # 経緯: CEOから「顧客一覧のCSVエクスポートでダウンロードすると文字化けしている」との報告。
  # 日本語版Windowsの Excel は、BOMの無いCSVをCP932（Windows-31J）として開くため、UTF-8で
  # 書かれた日本語がすべて化ける。BOMを付ければ Excel はUTF-8と判定して正しく開く。
  #
  # CP932へ変換する案は採らない。①・髙・〜・― などCP932に対応字が無い文字が実データに現れ、
  # `String#encode` が例外になるか（invalid/undef: :replace を付ければ）文字が欠落するため、
  # 「化けない代わりにデータが壊れる」形になるだけで解決にならない。
  #
  # 付与はここ1箇所だけで行う。Admin::CsvExportsController#show は file_data をそのまま
  # send_data するので、BOMを二重に付ける経路は作らないこと。
  BOM = "\uFEFF".freeze

  def perform(csv_export_id)
    export = CsvExport.find(csv_export_id)
    user   = export.requested_by
    Current.user = user

    target  = EXPORT_TARGETS.fetch(export.resource_type)
    scope   = Pundit.policy_scope!(user, target[:klass])
    columns = target[:columns]

    csv = CSV.generate(headers: true) do |rows|
      # 1行目は日本語の見出し（columns の値）、2行目以降は同じ順序のカラム（columns のキー）の生値。
      # Hashは挿入順を保つので、見出しとデータの並びは EXPORT_TARGETS の記述順で必ず一致する。
      rows << columns.values
      scope.find_each { |record| rows << columns.keys.map { |c| record.public_send(c) } }
    end

    export.update!(status: "completed", file_data: BOM + csv, row_count: scope.count)
  rescue StandardError => e
    export&.update!(status: "failed", error_message: e.message)
    raise
  ensure
    Current.user = nil
  end
end
