# P4-12 設計案：画面ごとのデータ出力カスタマイズ（エクスポートプロファイル一般化）

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/export-profile-design.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。フェーズ対応: **R6（運用強化）— 複数プロファイル対応は未実装**。基盤（`CsvExport` + `CsvExportJob` の非同期エクスポート）は **R2/R4 で実装済み**（04 R2タスク7）。突合対象: `app/models/csv_export.rb` / `app/jobs/csv_export_job.rb` / `app/controllers/admin/csv_exports_controller.rb` / `app/controllers/admin/{customers,orders}_controller.rb#export` / `app/policies/csv_export_policy.rb` / `db/schema.rb`（csv_exports）/ `spec/jobs/csv_export_job_spec.rb`。
> - §1 は「Laravel現行の分析」から「**Rails版の現状（R4時点）**」に書き換えた。Laravel時代の 4 Job 構成（users/agency_groups/agencies/sales_representatives）は Rails版には存在せず、Customer / Order の 2 エンティティ（`CsvExportJob::EXPORT_TARGETS`）のみが実装済み。**Store は未対応**（04 R2見直しレビュー残タスク）。
> - R5 D-P8（請求用受注データCSV。`payment-integration.md` §4-8）の載せ先を §7 に新設。
> - Laravel時代のフェーズ番号（P4-12 / P4-1 等）は残し、対応する R フェーズを併記する（P4-1 参照制御 = **R1 で実装済み**、P4-12 = **R6**、P4-16 監査ログCSV = R6、P4-20 集計 = R6、P4-22 取込 = R6）。

> **ステータス: 設計案 → Q-14 は本書の推奨どおり仕様決定済み（D-13・2026-07-26。`development-plan.md` §8: config管理 v1・将来ハイブリッド移行可の構造）。実装は R6（未着手）。**
> 作成日: 2026-07-26 ／ 参照: `development-plan.md` §3 P4-12、`design/business-flow-analysis.md` §6-2、
> `design/legacy-research/04-requirements-inventory.md`、`design/payment-integration.md` §4-8（D-P8）、`04-implementation-plan.md` R5/R6

---

## 1. 現状分析

### 1-1. 現行実装の構造（Rails版・R4 時点。コード根拠）

| 層 | ファイル | 実態 |
|---|---|---|
| トリガー | `app/controllers/admin/customers_controller.rb#export` / `orders_controller.rb#export`（`POST /admin/customers/export`, `/admin/orders/export`。`config/routes.rb` `collection { post :export }`） | 各一覧画面の `button_to "CSVエクスポート"`（`app/views/admin/{customers,orders}/index.html.erb`）から POST → `CsvExport.create!(resource_type: "Customer"/"Order", requested_by: current_user, status: "pending")` → `CsvExportJob.perform_later` → `admin/csv_exports` 一覧へリダイレクト。**画面の検索条件（`params[:q]` / `params[:status]`）は引き継がれない**（全件＝policy_scope 範囲） |
| ジョブ | `app/jobs/csv_export_job.rb`（Solid Queue、`queue_as :default`） | `EXPORT_TARGETS`（固定 Hash: `"Customer" => {klass:, columns:}`, `"Order" => {klass:, columns:}`）で **エンティティ 2 種と出力列をハードコード**。`Pundit.policy_scope!(user, klass)` で実行者の参照範囲に絞り、`CSV.generate(headers: true)` で列名ヘッダ＋`record.public_send(col)` の生値を出力。`Current.user` を実行者に設定。失敗時は `status: "failed"` + `error_message` |
| 状態管理 | `app/models/csv_export.rb` ＋ `csv_exports` テーブル | UUID・`resource_type`（`EXPORTABLE_RESOURCE_TYPES = %w[Customer Order]` の inclusion validation）・`status`（pending/completed/failed）・`row_count`・`error_message`・**`file_data`（text 列に CSV 本文をそのまま保持。Active Storage/ファイル保存ではない）**・`requested_by_id`(FK users)。**`filters` 列・`expires_at` 列・定期削除は無い** |
| ダウンロード | `app/controllers/admin/csv_exports_controller.rb`（index / show） | `show` が `send_data export.file_data, filename: "#{resource_type.underscore}_#{id}.csv", type: "text/csv"`。ファイル名固定・**BOM なし UTF-8**・CSV 標準クォート（必要時のみ）・**CSVインジェクション対策（先頭 `=` `+` `-` `@` のサニタイズ）は無い** |
| 認可 | `app/policies/csv_export_policy.rb` | `index?`=true（Scope で自分の分のみ。staff は全件）、`show?`=staff or 本人。レイヤー1（`SystemPermission`）は `admin/csv_exports#index/show` と `admin/customers#export` 等のルート単位。**「この出力定義は誰が出せるか」の定義単位権限は無い**（旧 P4-12 タスク g） |
| フロント | ERB + Hotwire（決定B） | ボタン 1 個（エンティティ 1: 出力 1）。ポーリング UI は無く、一覧ページで手動リロード（Turbo Streams でのステータス更新は未実装） |
| テスト | `spec/jobs/csv_export_job_spec.rb` | 代理店ユーザの Customer/Order エクスポートに他代理店行が含まれないこと、`billing_password`（暗号化列）が列に含まれないことを検証済み |
| 関連フラグ | `agencies.csv_download_visible` / `agency_groups.csv_download_visible`（R1 実装済み。`Auditable` 追跡対象） | 管理画面で編集はできるが、**エクスポートボタンの表示制御・権限判定には未接続**（Column.md 由来の項目。R6 で定義単位権限と併せて意味づけする） |
| 設定 | （なし） | 出力レイアウトに関する設定は無い（Laravel の `config/csv.php` 相当も無し。取込側は `UserCsvImportJob` 内定数） |

> Laravel版との対応: `CsvExportController@store` + `JOB_MAP`（4 Job） → `Admin::{Customers,Orders}Controller#export` + `CsvExportJob::EXPORT_TARGETS`（2 エンティティ）。`csv_exports.export_type` → `resource_type`。`file_path` + `expires_at` + `csv-exports:cleanup` → `file_data`（DB 直保持・削除なし）。`CsvExportButton.vue` → `button_to`。

### 1-2. 「1画面:複数レイアウト非対応」の具体的な制約箇所（Rails版）

1. **`resource_type` = エンティティ名 = `EXPORT_TARGETS` のキーが 1:1 で固定**。
   「同じ案件一覧から『管理用フル出力』と『アシスト納品用』『請求用受注データ』を選ぶ」ことが構造上できない。
2. **列定義（`columns`）が `CsvExportJob` の Ruby 定数に固定**。列の増減・並び替え・ラベル付け（現状はカラム名がそのままヘッダ）・固定値の
   埋め込み・関連先の値（`agency.name` 等。現状は `agency_id` の UUID がそのまま出る）はすべてコード修正＋デプロイ。
3. **出力形式がジョブにハードコード**：UTF-8（**BOM なし**）、Ruby `CSV` 既定（LF 改行・必要時のみクォート）、ファイル名 `{resource_type}_{uuid}.csv` 固定。
   アシスト側が SJIS/CRLF/独自ファイル名規則を要求しても対応不可（→ タスク h）。CSVインジェクション対策も未実装。
4. **出力権限の粒度がない**：ルート単位の `SystemPermission`（`admin/customers#export` 等）と `CsvExportPolicy`（本人のみDL）のみで、「この定義は誰が出せるか」を定義単位で制御できない（→ タスク g）。`csv_download_visible` フラグは未接続。
5. **絞り込みの引継ぎがない**：一覧の検索条件（`q` / `status`）が渡されず常に全件。定義ごとの許可フィルタの宣言も無い（→ タスク f）。
6. **成果物が DB の text 列**：大量行（案件 90 フィールド×数万件）だと `csv_exports.file_data` が肥大化し、`index` 一覧のクエリにも影響しうる。定期削除も無い（→ タスク h と同時に Active Storage or 期限付き削除を検討）。
7. **Store 未対応**（04 R2見直しレビュー残タスク）。

### 1-3. §6-2 が示す本命ユースケース（アシスト納品用）

現行運用：`「7:作業進行依頼」で検索 → CSV DL → A列(顧客番号)〜CT列(契約者住所)を手で削除 →
不備チェック → ファイル名ルールで保存 → 他者目視ダブルチェック → 発注フォーム添付`。
新システムでは **「出力定義で最初から必要列だけ・正しい順で・固定値も埋めて出力」** し手作業を全廃する
（`business-flow-analysis.md` §6-2、設計原則 §10-4「出力は最初から完成形で出す」）。

### 1-4. 追加要望の周辺（legacy-research/04）

エクスポート「追加」の直接要望は §6-2 以外に見当たらないが、同族の将来ユースケースとして
**P4-16（監査ログ CSV。R6）・P4-20（集計 Excel 出力。R6）**、および **R5 D-P8（請求用受注データCSV。§7）** がある。P4-12 の一般化はこれらの受け皿になる
（P4-22 の外部 CSV「取込」は別物・対象外。取込側は `UserCsvImportJob` が R1 で先行実装済み）。

---

## 2. 出力定義（エクスポートプロファイル）のデータ構造案

`resource_type`（エンティティ）を **`profile_key`（出力定義）** に置き換える。1エンティティ＝N プロファイル。

```yaml
# 概念構造（v1 は config/csv_export_profiles.yml + 値オブジェクト CsvExportProfile として config 管理。§3 参照）
assist_delivery:                              # profile_key（安定識別子・csv_exports に記録）
  label: アシスト納品用                        # 画面表示名
  entity: order                                # 対象エンティティ（後述の CsvExport::Sources::OrderSource に対応）
  columns:
    # source: モデル属性 / リレーションパス / 変換名 / 固定値 の4種。いずれも「出力可能列カタログ」のキーのみ許可
    - { header: 店舗名,   source: store.store_name }
    - { header: 作業項目, source: product_option_names, transform: join_comma }
    - { header: 契約状態, source: contract_status,      transform: label:contract_status }
    - { header: 申込日,   source: ordered_at,           transform: "date:%Y/%m/%d" }
    - { header: 発注元,   fixed: 株式会社◯◯ }            # 固定値埋め込み
  filters: [status, agency_id, ordered_from, ordered_to]   # 許可フィルタの明示 whitelist
  default_filters: { status: "7:作業進行依頼" }              # §6-2 相当を初期適用
  format:
    encoding: CP932            # UTF-8 BOM / CP932(Windows-31J)。既定 UTF-8 BOM（Excel互換のため R6 で BOM 付きに変更。現行は BOM なし）
    eol: "\r\n"                # 既定 LF（Ruby CSV 現行）。納品用は CRLF 想定
    force_quotes: true         # true / false（Ruby CSV の force_quotes）
    sanitize: true             # CSVインジェクション対策（先頭 = + - @ をクォート/エスケープ。既定 ON）
  file_name: "assist_%Y%m%d"   # ファイル名規則（Q-15 で確定。既定は {profile_key}_{Ymd_His}）
  permission: export.assist_delivery   # 定義単位の出力権限（タスク g）
  screens: [admin/orders#index]        # どの画面のエクスポートメニューに出すか
```

設計上のポイント（Rails版）：

- **`columns.source` はコード側カタログで解決する**。任意の DB カラム名を定義に直書きさせない
  （`encrypted_password` / `billing_password` / `order_work_details.*_pass` 等の露出防止）。エンティティごとに「出力可能列カタログ」（`CsvExport::Catalogs::OrderCatalog` 等: source キー → 取得ラムダ）を
  コードで持ち、プロファイルはそのキーを並べるだけにする。カタログ生成時に `Model.encrypted_attributes` と `FormField::SYSTEM_COLUMNS` 相当（R3 の `allowed_target_columns_for` と同じ発想）を機械的に除外し、**暗号化列がカタログに載ることを spec で禁止する**（現行 `csv_export_job_spec` の「billing_password を含めない」テストを一般化）。`transform` も登録済み変換
  （bool_label / label:<status_master> / date:… / join_comma / fixed）のみ許可。
- **絞り込み引継ぎ**：一覧コントローラの検索条件適用ロジック（`Admin::OrdersController#index` の `q` / `status`）をエンティティ別
  `CsvExport::Sources::OrderSource`（`app/services/csv_export/sources/`）へ抽出し、一覧とジョブの両方から使う。プロファイルの
  `filters` whitelist と突き合わせて適用。画面の検索条件をそのまま `POST` する UX（Laravel現行）を Rails版でも採用し、`csv_exports.filters`(jsonb) に保存する。
- **P4-1（参照制御 = R1 実装済み）との連動**：`Source` は必ず `Pundit.policy_scope!(user, klass)` を起点にする（**現行 `CsvExportJob` が既にそうしている**。汎用化で崩さない）。**Solid Queue のジョブ内には認証コンテキストが無い**ため、`csv_exports.requested_by_id` から実行者を復元して `Current.user` に設定する（現行踏襲）。Laravel設計時の「P4-1 後着手」順序制約は Rails版では**解消済み**（§4）。
- **`csv_exports` テーブルは `resource_type` → `profile_key` に読み替え、`filters` jsonb / `expires_at` / `file_name` を追加**（migration。status/requested_by の仕組みは現行のまま。`resource_type` は移行期間中 `profile_key` から導出可能なので列名変更で対応）。
- **フロントは各一覧の `button_to` を、プロファイルが複数ある画面ではドロップダウン（`select` + Turbo Frame）化**（1画面:Nレイアウト対応）。`profile.screens` で表示画面を宣言し、`can_access_system_action?` ヘルパー（ftlog 流用）＋定義単位権限で表示制御。
- **PII（分類A: 氏名・電話・メール等）**: カタログには載せるが、プロファイル側で `pii: true` の列を含む場合はダウンロード時に `AuditLog`（action=csv_downloaded、metadata に profile_key/row_count）を必ず残す（`pii-handling-rules.md` の運用ルールとの整合。R6 で `Admin::CsvExportsController#show` に追加）。

---

## 3. Q-14 判断材料：config 管理 vs DB 管理（＋ハイブリッド）

### 3-1. 比較表（Rails版に読み替え）

| 評価軸 | A. config 管理（`config/csv_export_profiles.yml` + Ruby カタログ） | B. DB 管理（`csv_export_profiles` テーブル＋管理UI） | C. ハイブリッド（カタログ=コード／プロファイル=DB） |
|---|---|---|---|
| 変更頻度への適合 | ◎ レイアウト変更は委託先フォーマット改定時など**低頻度**想定。業務側が日常的に触る性質ではない | △ 高頻度変更なら有利だが、その需要は現時点で確認されていない（Q-15 も未確認） | ○ 低頻度前提なら過剰、将来高頻度化したら移行先として妥当 |
| デプロイ要否 | × 変更のたびにデプロイ | ◎ 画面から即時変更 | ○ 列カタログ追加はデプロイ、並び・選択は画面 |
| 監査性 | ◎ git 履歴＝完全な変更履歴・PR レビュー可能。**納品フォーマット破壊の事故をコードレビューで防げる** | ○ Rails版は `Auditable` concern（R0 実装済み）に `TRACKED_FIELDS` を 1 行足せば変更履歴は取れる（Laravel設計時の「別途実装」よりは軽い）。ただし列定義 jsonb の差分は読みにくい | ○ カタログは git、プロファイル変更は Auditable |
| 実装コスト | ◎ 小：YAML＋値オブジェクト＋汎用 Job＋writer 抽象化のみ | × 大：テーブル設計・CRUD UI（Hotwire）・列指定の安全性検証（任意カラム露出防止）・シーディング・`CsvExportProfilePolicy` | △ 中：B からUIを簡略化できるが DB・UI は必要 |
| 安全性（情報露出） | ◎ 出力可能列がコードで閉じる | △ UI で任意列を選ばせる場合、機微列（認証情報・個人情報）の露出制御を別途設計（R3 の `FormField#target_column` ホワイトリスト事故＝commit `7cb7dc4` の再演リスク） | ○ カタログがコードなら A と同等にできる |
| R3 フォーム定義（FormTemplate/FormStep/FormField）との整合 | △ **Rails版ではフォーム定義は DB 管理（R3 実装済み）**。Laravel設計時の「同型（コード定数）」根拠は Rails版では成立しない。ただし「書き込み可能列のホワイトリストはコード（`FormField.allowed_target_columns_for`）」という**カタログ=コードの原則は共通** | ○ 「定義=DB」で R3 と揃う | ◎ **「カタログ=コード／定義=DB」が R3 の実装パターン（`allowed_target_columns_for` + DB の form_fields）と完全に同型** |
| Q-15 未確認との相性 | ◎ フォーマット確定後にコードで一発追加。確定前に UI を作り込む無駄がない | × フォーマット不明のまま汎用 UI を設計するとやり直しリスク大 | △ 同左（UI 部分） |

### 3-2. 推奨（1案）

> **推奨：A. config 管理（`config/csv_export_profiles.yml` を `Rails.application.config_for` で読み、`CsvExportProfile` 値オブジェクト＋レジストリ `CsvExportProfile.find(profile_key)` で解決）を v1 として採用。**
> ただし `profile_key` を安定識別子とし、プロファイルを値オブジェクト経由で解決する構造にして、
> **将来 C（ハイブリッド）へ無改修に近い形で移行できる設計**にしておく（YAML の 1 エントリ＝将来の `csv_export_profiles` 1 行）。

根拠（Rails版で見直し）：

1. **変更頻度が低く、変更の影響が重い**：アシスト納品フォーマット・請求用CSV（§7）の誤りは委託先への納品事故・請求停止に直結する。
   git 履歴＋PR レビューで守れる config 管理が、監査性・安全性の両面で運用実態に合う。
2. **R3 との整合は「カタログ=コード」で保たれる**：Laravel設計時の根拠（フォーム定義もコード定数）は Rails版では崩れた（R3 でフォーム定義は DB 化済み）が、「書き込み/読み出し可能な列の範囲はコードで閉じる」原則は R3 の `FormField.allowed_target_columns_for` と同じであり、v1 を A、需要が出たら C へ昇格するのが R3 と最も整合的。**A→C の昇格を最初から想定した構造にする（レジストリの実装差し替えのみで済むこと）を v1 の受け入れ条件とする。**
3. **Q-15 未確認の今、DB 化＋管理 UI は投資の先走り**：要求（業務側が自分で列をいじりたいか）が
   確認されてから C へ昇格すればよい。

DB 化（C）を再検討するトリガー（明文化しておく）：
- 業務側から「デプロイ待ちなしで列を変えたい」要望が実際に出たとき
- プロファイル数が概ね10を超え、YAML 管理の見通しが悪化したとき
- 代理店ごとに異なる出力レイアウト（`csv_download_visible` の延長）が要件化したとき

---

## 4. 実装ステップ案（P4-12 タスク a〜h への対応・Rails版 R6）

**順序制約の確認**：development-plan.md P4-12 は「**P4-1 の後に着手**」（L221）。理由は §2 のとおり、
汎用 Job がキュー内で実行者の参照可能範囲を再現する必要があるため。**Rails版では P4-1（Pundit `policy_scope`）は R1 で実装済みで、現行 `CsvExportJob` も既に `Pundit.policy_scope!` を通しているため、この前提条件は満たされている。** 残る順序制約は「Step 4 の汎用ジョブが現行と同じ `policy_scope!` 経路を維持すること」を回帰 spec で担保することのみ。

| Step | タスク | 内容（Rails版） | 対応 |
|---|---|---|---|
| 1 | a, b | 本設計の確定（プロファイル構造 §2・Q-14 決定 §3）。`config/csv_export_profiles.yml`＋`CsvExportProfile` 値オブジェクト（`app/models/csv_export_profile.rb`。ActiveModel）＋レジストリ実装。既存 2 種を `customer_admin` / `order_admin` プロファイルとして定義 | 先行可 |
| 2 | h | CSV writer 抽象化（`CsvExport::Writer`）：encoding（UTF-8 BOM / CP932。`String#encode("Windows-31J", invalid: :replace, undef: :replace)`）・eol（LF/CRLF。`CSV.generate(row_sep:)`）・force_quotes・sanitize を profile の `format` から適用。既定値は**現行挙動（UTF-8 / LF）に固定し既存 2 種の出力バイト列を不変に保つ**（BOM 付与への変更は業務確認のうえ別途）。併せて `csv_exports.file_data` の text 直保持を継続するか Active Storage へ移すかを判断（`expires_at` + `config/recurring.yml` の定期削除 `CsvExport.prune_expired!` は本 Step で追加） | 先行可 |
| 3 | c | トリガー一般化：`Admin::CsvExportsController#create`（`POST /admin/csv_exports` に `profile_key` + `filters` を受ける）へ集約し、`Admin::{Customers,Orders}Controller#export` はそれを呼ぶ薄いラッパー（または削除してルートを移す。`SystemPermission` の sync に影響するため RoleSeeder の既定マトリクス更新も同時に）。バリデーション＝レジストリ存在＋定義単位権限（Step 6）+ `filters` whitelist | Step 1 後 |
| 4 | d | 汎用 `CsvExportJob`：`EXPORT_TARGETS` を廃し profile 解決 → `Source`（`policy_scope!` 起点＋filters）→ カタログ＋transform で行生成 → Writer。既存 2 種は同等プロファイルとして移行し、**出力バイト列一致を回帰 spec で担保**（`spec/jobs/csv_export_job_spec.rb` の 3 ケースは維持） | Step 1〜2 後 |
| 5 | f | 絞り込み引継ぎ：一覧の検索条件を hidden で POST・`csv_exports.filters` に保存・profile の `filters` whitelist 適用＋`default_filters`。ボタンのドロップダウン化（ERB + Turbo Frame） | Step 4 と同時 |
| 6 | g | 出力権限：profile の `permission` を create 時に検査。実装候補は (i) `SystemPermission` に仮想ルート（`csv_export_profiles#assist_delivery` 等）を登録してロールマトリクスで管理、(ii) `CsvExportProfilePolicy`（Pundit）で `staff_scope?` / `agency.csv_download_visible` を見る、の 2 案。**(ii) を推奨**（マトリクスを汚さず、`csv_download_visible` フラグの意味づけができる）。download は現行どおり本人 or staff のみ | Step 3 と同時 |
| 7 | e | **アシスト納品用プロファイル実装**：Q-15 ヒアリング結果（列・順序・固定値・ファイル名規則・文字コード）を YAML に起こす。§6-2 の「目視ダブルチェック」代替として、出力前バリデーション（必須項目欠落の検出→エラーレポート）を同プロファイルに付ける | **Q-15 確定後** |
| 8 | （新設）| **Store プロファイル追加**（04 R2見直しレビュー残タスク「Store向けCSV非同期エクスポート未実装」の解消）。`StorePolicy::Scope`（customer 経由）を Source に使う | Step 4 後 |
| 9 | （新設）| **請求用受注データプロファイル**（R5 D-P8。§7）。R5 で `EXPORT_TARGETS` に先行追加した場合は本 Step で YAML プロファイルへ移設 | R5 完了後 |

## 5. Q-15（アシスト納品フォーマット未確認）との切り分け

| 区分 | 内容 |
|---|---|
| **Q-15 未確定でも先行できる** | Step 1〜6・8 の全部：プロファイル基盤・writer 抽象化（CP932/CRLF/囲み対応の**機構**）・トリガー/Job 一般化・既存 2 種のプロファイル移行・絞り込み引継ぎ・出力権限・Store 追加。アシスト用プロファイルの**プレースホルダ**（entity=order、default_filters=「7:作業進行依頼」、列は仮）作成まで可 |
| **Q-15 確定が必要** | Step 7 の中身：正確な列構成・列順（「A〜CT列削除後に残る列」の実リスト）・固定値の値・ファイル名規則・文字コード/改行/囲みの**最終値**・出力前バリデーションの必須項目定義 |
| **含意** | P4-12 の工数の大半（基盤一般化）は Q-15 をブロッカーにしない。Q-15 は「最後の1プロファイル分の設定作業」に局所化される。ただし **Q-15 ヒアリングは長リードになり得るため今から依頼**しておくのが安全（development-plan の「長リード先行」原則と同じ扱い）。§7 の請求用CSV列定義（payment-integration.md 論点14）も同じく長リード |

---

## 6. 関連未決事項

- **Q-14**：✅ 仕様決定済み（D-13・2026-07-26）。本書 §3-2 の推奨（config 管理 v1・将来 C へ昇格可能な構造）を採用。Rails版では YAML + 値オブジェクトで実装する。
- **Q-15**：アシスト納品フォーマット要ヒアリング（§5）。
- **（新規）BOM 付与**：現行 R4 実装は BOM なし UTF-8。Excel で開く運用が主なら既定を UTF-8 BOM に変えるべきだが、既存出力の互換性（現状は利用者が限定的）を含め R6 着手時に決める。
- **（新規）成果物の保存先**：`csv_exports.file_data`（text 列）継続 vs Active Storage。大量行の運用実績が無いため R6 Step 2 で判断。
- **（新規）`csv_download_visible`（agencies / agency_groups）の意味づけ**：R1 で列だけ実装済み・未接続。定義単位権限（Step 6）で「代理店にエクスポートを許可するか」のフラグとして接続する案を推奨。
- 将来：P4-16（監査ログ CSV）・P4-20（集計 Excel）は本レジストリの拡張（Writer に xlsx 追加等。gem 選定要）で受けられる。いずれも R6。

---

## 7. R5 D-P8「請求用受注データCSV」の位置づけ（2026-08-19 新設）

`payment-integration.md` §4-8 / D-P8（CEO決定 2026-07-27）: 継続課金の売上処理は TBSS スコープ外で、新システムは **TBSS が突合に使う請求用受注データを CSV 出力できること**のみを担う。必要列は TBSS ヒアリング待ち（同書 論点14。最低限: 顧客/案件の特定キー・`netmove_member_id`・支払方法・プラン/月額・おまとめ請求と先案件番号・契約開始/解約/キャンセル日・ステータス）。**稼働後最初の月次請求（25日前後）までに必須**＝R8 カットオーバー計画の締切。

| 選択肢 | 内容 | 評価 |
|---|---|---|
| (1) R5 で `CsvExportJob::EXPORT_TARGETS` に `"BillingOrder"` エントリを追加（`klass: Order`, 列は請求用） | 現行基盤への 1 エントリ追加。`CsvExport::EXPORTABLE_RESOURCE_TYPES` にも追加。トリガーは `Admin::OrdersController#export_billing` 等 | **推奨（先行実装）**。R6 の汎用化を待たずに締切を守れる。`payment-integration.md` §4-8 の Rails版注記と一致。ただし「1エンティティ=1出力」の制約は残るため R6 で YAML プロファイルへ移設する（Step 9） |
| (2) R6 の汎用化を先に完了させ、その 1 プロファイルとして実装 | 設計上は最も素直 | R5 と R6 の順序が入れ替わり、請求 CSV が R6 完了まで出ない。締切リスク大 |
| (3) R6 汎用化のうち Step 1〜4（基盤）だけを R5 に前倒し | 汎用化を分割して R5 に一部取り込む | R5（決済・契約状態機械）の負荷を増やす。R5 のスコープ拡大は避けたい |

**提案: (1) を採用し、04 R5 節「請求用受注データCSV出力の実装先を確定する」を「R5: `EXPORT_TARGETS` への `BillingOrder` 先行追加（列は TBSS ヒアリング後に確定。ヒアリング前はプレースホルダ列で spec だけ先に書く）／R6: 本設計の Step 9 で YAML プロファイルへ移設」と確定する。** 請求用 CSV は代理店ユーザに出させる理由が無いため、トリガーは staff 限定（`SystemPermission` の既定マトリクスで admin/実務運用者のみ）とし、`policy_scope!` は staff=全件でよい。

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-26 | 初版（設計案）。Laravel現行 4 Job 構成の分析・プロファイル構造・Q-14 比較・実装ステップ・Q-15 切り分け |
| 2026-08-19 | Rails版改訂（R6・複数プロファイルは未実装）。§1 を Rails 現行実装（`CsvExport`/`CsvExportJob::EXPORT_TARGETS`（Customer/Order）/`Admin::CsvExportsController`/`CsvExportPolicy`）の現状分析に書き換え、Store 未対応・filters/expires_at 無し・BOM/サニタイズ無し・`csv_download_visible` 未接続を差分として明記。§2 を YAML/値オブジェクト/`policy_scope!`/Hotwire に読み替え。§3 の「P2-1 と同型」根拠を R3（フォーム定義は DB・カタログはコード）に合わせて修正。§4 の P4-1 順序制約は R1 実装済みで解消と判定、Step 8（Store）/9（請求用）を新設。§7（R5 D-P8 の位置づけ）を新設 |
