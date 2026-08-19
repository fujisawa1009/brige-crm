# 開発・移行作業中の PII 取扱ルール（Q-A 対応）＋ PII暗号化方針（Q-D）

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/pii-handling-rules.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。フェーズ対応: **R2（PII暗号化の実装先行）／R7（データ移行・ETL）／R8（release C-3・C-5・G-8）**。ディレクトリ・クラス名を Rails 版（`app/models/concerns`・`encrypts`・`filter_parameter_logging`・`AuditLog`）へ書き換え、3分類ルールは維持。§5 に **Q-D の現状（分類B=実装済み／分類A=未決・実装先行）と決定候補案** を追記。実装突合日: 2026-08-19。

> ステータス: **ドラフト（決定者確認待ち）** — Q-A（本書 §1〜§4・§6・§7）と Q-D（§5）ともに正式決定は未了
> 作成日: 2026-07-26（Laravel版）／Rails版改訂: 2026-08-19
> 対象タスク: `../development-plan.md` Q-A「原資料の外部認証情報・実顧客個人情報の取り扱い」（**要対応**）／
> 同 Q-D「顧客SNSアカウント・パスワードの保持可否（保持なら暗号化）」（**未確認**。04 リスク5「R2着手前に確定が必要」→ 実装が先行し決定記録が無い）
> 関連: `release-readiness.md` C-3（顧客SNS認証情報の暗号化）・C-5（個人情報の取り扱い）・G-8（原資料の秘匿情報の取り扱い）／
> `04-rails-implementation-plan.md` R2見直しレビュー残タスク「PII方針（Q-D）」・リスク5／
> `../development-plan-review-20260726.md` §3-2（Q-A を担当・完了条件付きタスクに昇格せよとの指摘。※同ファイルは旧Laravel側に残存）
>
> 本書の各項目は【既存運用の明文化】【提案】【実装済み】を区別して記載する。
> 【提案】の項目は現時点で運用実績・合意が確認できていないもので、決定者承認により確定する。
> 【実装済み】は brige-crm の現行コード（`app/models` / `config` / `spec`）で裏付けが取れているもの。

---

## 1. 対象の定義（3分類）

開発・移行作業中に触れる秘匿情報を以下の3分類で扱う。分類ごとに漏えい時の影響と対処が異なる。

| 分類 | 内容 | 実在が確認されている所在 | Rails版の保存先（現行スキーマ）と保護状態 |
|---|---|---|---|
| **A. 実顧客PII** | 氏名・カナ・住所・電話・携帯・メールアドレス・請求書送付先。掲示板の投稿本文（実名でのやり取り） | DB退避データ `CSV.zip`（9ファイル・29MB・全件。掲示板 bridge 77,981 ＋ bridge_plus 342,594 件に**全顧客とのやり取りが実名で含まれる**：`legacy-research/00` §2・`08` §1）／案件CSV（all_bridge 1,206・all_bridge_plus 2,092 件、238フィールドに契約者情報を含む：`legacy-research/11` §2） | `customers`（name / contractor_name_kana / representative_name / contact_name / postal_code〜address_detail / phone / mobile_phone / fax_number / email / invoice_* / sms_mobile_number 等）、`stores`（店舗名・住所・電話）、`orders.finance_*`（設置先住所・電話）、`inquiry_messages.body`（問い合わせ本文）。**平文保存**（`encrypts` 無し）。保護はアクセス制御（RBAC＋Pundit スコープ＋IP許可リスト）と監査ログ（`AuditLog`）による。**暗号化しない方針の正式決定は無い（→ §5 決定待ち）** |
| **B. 外部認証情報** | SNSアカウントのID/パスワード（Instagram・Facebook・Google）・システムアカウントID/PASS・請求パスワード・現行システム（ジャスミン等）のログイン情報 | 案件CSVの238フィールド中に**平文で存在**（63/166 システムアカウント、66/67 Instagram、126/127 Facebook、236/237 Google の各ID/PASS：`legacy-research/11` §4）。業務フローpptx にも外部システムのログインID/パスワードが平文で記載（`business-flow-analysis.md` §0） | `order_work_details`（system_account_id/pass・google_account_id/pass・instagram_id/pass・facebook_id/pass の8列）と `orders.billing_password` に **`ActiveRecord::Encryption`（`encrypts`・非決定的）で暗号化保存【実装済み・R2】**。申込フォームの `target_column` ホワイトリストから自動除外、`Auditable::TRACKED_FIELDS` からも除外。spec: `spec/models/order_work_detail_spec.rb`（8列が暗号化対象・DB上は平文でない） |
| **C. 決済関連情報** | 決済会員ID（ネットムーブ）・支払方法・信販（設置先住所・電話含む）・販管売上伝票番号・おまとめ請求情報 | 案件CSVの決済・信販フィールド群（`legacy-research/11` §3）。※カード番号そのものは現時点の原資料から確認されていない（決済はネットムーブ側保持）。移行・テストで新たに現れた場合は本分類として扱う | `customers.netmove_member_id` / `netmove_registered_at`、`orders.payment_method` / `finance_*` / `sales_mgmt_slip_number` / `bundled_billing` / `bundle_target_order_number`。**平文保存**。決済トランザクション（`payment_transactions` 等）は R5 未実装。`netmove_member_id` は申込フォームのホワイトリストから除外されていない（`form-template-mapping.md` §9-2 #2） |

> 判断に迷うものは**上位（より厳しい）分類**として扱う。B（認証情報）は「個人情報」でなくても
> 第三者アカウントへの不正アクセスに直結するため、A と同等以上の厳格さで扱う。

### 1-1. Rails版で既に効いている横断的な保護機構【実装済み】

| 機構 | 実装箇所 | 内容 |
|---|---|---|
| カラム暗号化 | `app/models/order_work_detail.rb`（8列）・`app/models/order.rb`（`billing_password`） | `encrypts`（非決定的）。鍵は Rails credentials（`active_record_encryption.*`。`config/credentials.yml.enc`。本改訂では機密のため中身未確認）。等価検索は行わない前提 |
| ログの秘匿値フィルタ | `config/initializers/filter_parameter_logging.rb` | `:passw, :pass, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc`（部分一致）。R2見直しレビューで `*_pass` 系にマッチするよう `:pass` を追加済み。※分類Aの氏名・電話・住所はフィルタ対象外（email のみ） |
| 監査ログの追跡列制限 | `app/models/concerns/auditable.rb`（`TRACKED_FIELDS`）→ `AuditLog` | 秘匿値・暗号化列・本文（`InquiryMessage.body` / `Notification.body`）は追跡対象外。Customer は `name status agency_id sales_representative_id applied_at contracted_at` のみ差分記録（電話・住所・メールは記録しない） |
| 申込フォームの一時データ | `app/models/application.rb`（`form_data` jsonb）・`Form::ApplicationSubmissionService` | 申込完了時に `form_data` を空にする（平文残存対策）。`Application` は意図的に `Auditable` を include しない |
| フォームからの秘匿列への書き込み防止 | `FormField.allowed_target_columns_for` | `encrypts` 列・外部キー・採番列・status を target_column に指定不可（R3見直しレビュー） |
| 参照制御・アクセス制御 | `app/policies/*`（Pundit `policy_scope`）・`SystemPermissionChecker`（RBAC）・`IpAllowlistEntry`・メールOTP | 代理店=自代理店のみ・グループ=配下のみ。管理画面はフェイルクローズ |
| CSVエクスポート | `CsvExport` + `CsvExportJob`（Active Storage・`Disk` サービス） | 生成物は要求者本人のみダウンロード可（`Admin::CsvExportsController`）。**保存先はローカル `storage/`（gitignore 済み）。保持期限・自動削除は未実装（→ §2-2 提案）** |

---

## 2. 保管ルール

### 2-1. 原資料は `private/` 配下限定・コミット禁止【既存運用の明文化】

- 原資料（業務フローpptx・DB退避データ CSV.zip・案件CSV 等）は親リポジトリの
  `private/ジャスミン資料/` 配下に置く。**リポジトリ外・コミット禁止**
  （`business-flow-analysis.md` 冒頭に明記済みの既存運用）。
- 機械的担保: 親リポジトリ `ai-auto-company/.gitignore` の `private/`（2026-08-19 時点 38 行目）により
  `private/` 配下全体が git 追跡対象外であることを確認済み
  （`git check-ignore -v private/ジャスミン資料` → `.gitignore:38:private/` を 2026-08-19 に再検証済み）。

### 2-2. 本リポジトリ（brige-crm）側の退避データ置き場【既存運用の明文化＋提案】

- 【実装済み】Rails 標準の `.gitignore` により `/storage/*`（`!/storage/.keep`）と `/tmp/storage/*` は追跡対象外。
  Active Storage（`Disk` サービス）の実体・CSVエクスポート生成物・移行の中間ファイルはここに置けば git には乗らない。
- 【差分】旧Laravel側にあった `requirements/input/`（ディレクトリだけ追跡・中身は ignore）は **brige-crm には存在しない**。
  人が置く入力素材（再エクスポートCSV等）の受け口が必要になった時点で、同じ方式（`!requirements/input/` ＋ `requirements/input/*`）で
  `.gitignore` に追加する【提案・R7 着手時】。
- 【提案】移行作業でCSVをリポジトリ内へ持ち込む必要がある場合は、上記**のみ**を使用する。
  用途の使い分け: 人が置く入力素材は `requirements/input/`（作成後）、アプリ/ETLコード（rake タスク・`rails runner`）が読み書きするものは
  `storage/private/etl/` 配下（→ §4-1）。それ以外の場所（`spec/fixtures/`・`spec/factories/`・`db/seeds*`・
  ドキュメント配下等）への実データ配置は禁止。
- 【提案】CSVエクスポート生成物（`CsvExport` の Active Storage 添付）は分類A を丸ごと含むため、**保持期限（例: 7日）を設けて
  Solid Queue recurring で自動削除する**ジョブを R6 で追加する（現状は無期限に残る）。

### 2-3. 追加の機械的担保【提案】

- 実データファイルの命名規約を `*.real.csv` / `real-*` に統一し、両リポジトリの `.gitignore` に
  パターンとして追加する（置き場所を誤ってもファイル名で二重に防ぐ）。
- CI（`.github/workflows/ci.yml`。既に `authorization_guard` の grep ガードジョブあり）または pre-commit に
  「電話番号・メールアドレスらしき文字列が新規追加行に大量に含まれる場合に警告」する
  簡易チェックの追加を検討する。※現時点では未実装のため提案扱い（旧Laravel側の `ci-local.sh` 系フックは brige-crm には無い）。

---

## 3. 使用ルール（設計・調査・検証での扱い）

### 3-1. 設計書・調査ノートへの転記はマスク必須【既存運用の明文化】

`legacy-research/` で既に実践されている方式を**標準**とする:

- **個票（個別レコードの値）を転記しない。構造・対応・件数のみ記載する。**
  - 実例: `08` 「⚠️ 実データ（実名・実顧客とのやり取り）を含む。移行設計時のみ扱い、個票を転記しない」
  - 実例: `09`/`10`/`11` 「⚠️ 実データ（PII）を含む。値は転記せず、構造・対応（ルール）のみ記載」
  - 実例: `13` 「回答本文は転記せず、構造・型・投入方針のみ記載」
  - 実例: `00` §2 データファイル一覧「件数・構造のみ・全件出力しない」
  - 実例: `business-flow-analysis.md` §0 「本書へは一切転記していない」
- 実データを扱う文書は**冒頭に ⚠️ 注意書きを必ず置く**（上記各ノートの体裁を踏襲）。
- 【提案】値の例示がどうしても必要な場合の書式を統一する:
  氏名→「山田太郎（架空）」等の**架空値に差し替え**、コード・IDは**桁数と型のみ**
  （例:「6桁数値」）、メール→`user@example.com`。原データの一部を伏字にした
  「実データ由来のマスク値」（例: `090-****-1234`）は復元リスクがあるため使わない。

### 3-2. サンプル検証・テストでの扱い【提案】

- 実データを使った検証（例: `11` §7 の「契約者住所パース可否をサンプルで確認」）は
  **`private/` または §2-2 の gitignore 済みディレクトリ内で完結**させる。検証結果として
  文書へ書けるのは成功率・失敗パターンの類型・件数まで（個票不可）。
- 自動テスト（`spec/`）・シーダー（`db/seeds.rb`・`app/services/*_seeder.rb`）には実データを**一切使わない**。
  FactoryBot / Faker による架空データのみ（現行 `spec/factories/*` は全て架空値。`db/seeds.rb` の開発用管理者は `admin@example.com`）。
- 検証用の一時スクリプト出力（dump・ログ）も §2-2 のディレクトリ外に書き出さない。
- 【実装済み】`Rails.logger` に流れるリクエストパラメータは `filter_parameter_logging` で秘匿値がマスクされる（§1-1）。
  ただし分類Aの氏名・電話・住所は対象外のため、ジョブ・サービスの `Rails.logger` 出力に**レコード実値を書かない**
  （`UserCsvImportJob` の現行実装は件数と行番号のみ。この慣行を維持）。

### 3-3. AIツール・外部サービスへの投入可否【提案】

- **可**: ローカルで完結する処理（本リポジトリ内での Claude Code / ETLスクリプト実行）で、
  出力（コミット・設計書）に個票を残さないこと（§3-1）を条件とする。
  ※既に legacy-research 作成過程で原資料をAIが読んで構造分析する運用実績があるため、
  「ローカルAI読取まで禁止」は現実と乖離する。禁止するのは**成果物への個票残存**。
- **不可**: 以下への実データ投入は禁止。
  - Web版の外部AIサービス・翻訳サービス等、履歴が第三者サーバに残るものへの貼り付け
  - Notion / Slack / Google Drive 等の共有サービスへの実データファイルのアップロード
  - 外部への調査依頼・レビュー依頼（codex 等の他社AI CLIを含む）のプロンプトへの個票貼付
- 分類B（認証情報）は特に、**いかなる外部送信も禁止**（マスク済みでも桁・形式から推測されうるため
  「4文字英数」のような型情報のみ可）。

### 3-4. 共有範囲【提案】

- 原資料の閲覧・複製は本プロジェクトの開発作業者に限定する。
  委託先（アシスト・アイフラッグ）との情報連携範囲は別論点（`release-readiness.md` G-7）であり
  本書のスコープ外だが、**開発都合で原資料を委託先へ渡さない**ことだけ本書で定める。
- `business-flow-analysis.md` §0 が提起している「資料の共有範囲の見直しと記載例の匿名化」の
  運用側（発注元）への提起は、本ルール確定後に別途実施する（→ §7 完了条件）。

---

## 4. 移行作業時のルール（ETL）【R7】

### 4-1. ETL中間ファイルの置き場所と削除【提案】

- ETL（`legacy-research/09` の整形設計。Rails版では rake タスク／`rails runner` で実装）が生成する中間ファイル
  （文字コード変換後CSV・分割列結合の中間形・クレンジング差分・エラーレコード退避）は
  **`storage/private/etl/` 配下に限定**する（`/storage/*` gitignore 済み・§2-2）。
- 中間ファイルは**フェーズ完了ごとに削除**する。少なくとも以下のタイミングで削除を必須とする:
  - 移行リハーサル（release B-7）各回の終了時
  - カットオーバー（B-9）完了後の検収確認をもって**全削除**
- 削除の実施は移行手順書（P5-5 → R7 の成果物）にチェック項目として組み込む。

### 4-2. 名寄せ表のPII含有への対応【提案】

- 名寄せ表（P5-5 → R7 律速3点の1つ。掲示板投稿者の手入力文字列→新IDの対応表、
  グループ/代理店/営業担当CD→UUID対応表。手順は `name-matching-process.md`）は、その性質上**氏名・組織名の実値を含まざるを得ない**。
- したがって名寄せ表は「設計書」ではなく**移行データそのもの**として扱う:
  - 置き場所は §4-1 と同じ `storage/private/etl/` 配下（または `private/ジャスミン資料/` 配下）。
    リポジトリの `requirements/` 配下には置かない。
  - 設計書側（`legacy-research/10` 等）に書くのは名寄せ**ルール**（キー・優先順位・件数）のみ。
  - 反復検証で長期間残るため、削除タイミングは §4-1 と同じ（カットオーバー検収後に全削除）。

### 4-3. 移行ログ・エラー出力【提案】

- ETLの実行ログにレコード実値を出さない（行番号・キー項目のコードのみ）。
  エラーレコードの実値確認が必要な場合は §4-1 の退避ファイルを直接見る。

### 4-4. 分類B（暗号化列）への load【提案・Q-D 決定後に確定】

- `order_work_details` の8列と `orders.billing_password` は `encrypts` 済みのため、ETL は **必ず ActiveRecord モデル経由（`OrderWorkDetail.create!` / `update!`）で書き込む**
  （`COPY` や生 SQL の bulk insert では暗号化されず平文が入る）。件数は最大 2,092 件（bridge_plus 案件）程度のため性能上の問題は無い。
- Q-D で「運ばない」となった場合はこれらの列を load 対象から外し、隔離した中間ファイルごと §4-1 のタイミングで削除する。

---

## 5. Q-D — PII暗号化方針の現状と決定待ち事項

本書は当初「**開発・移行作業中**の取扱」を定めるものだったが、Rails版では R2 実装が Q-D に先回りしたため（03§5「WorkDetail の SNS認証情報等は
`ActiveRecord::Encryption` で暗号化保存を既定にする（Q-D への先回り提案）」）、**実装の現状と、なお決定が必要な範囲**を本節に整理する。

### 5-1. 現状（2026-08-19 実装突合）

| 論点 | 状態 | 根拠 |
|---|---|---|
| Q-D 本来の論点「平文SNS認証情報（分類B）を新システムへ運ぶか」 | ✅ **2026-08-19 CEO決定: 運ぶ**（既存顧客のSNS作業を移行後も継続するため。R7 ETLで取り込む） | `development-plan.md` Q-D-1。`legacy-research/11` §4 のマッピングどおり保持する |
| 分類B の保存方式 | ⚠️ **2026-08-19 CEO決定（Q-45）で暗号化を廃止し平文保存へ変更**。従来の `encrypts`（非決定的）9列（`OrderWorkDetail` 8列 + `Order#billing_password`）は全て除去し、**本システムに `ActiveRecord::Encryption` の適用箇所は存在しない** | 変更理由: BRIDGE_PLUS申込フォームでInstagram ID/パスワードを必須入力にする業務要件（2026-08-18浅賀MTG・Q-45）に対し、暗号化列は `FormField.allowed_target_columns_for` から機構的に除外される設計だったため衝突した。秘書から「①`encrypts`は非決定的暗号のためスタッフは管理画面で従来どおり値を読めており業務影響は無い ②必須化できない原因は暗号化ではなくホワイトリスト設定で、専用ステップ実装なら暗号化のまま必須化できる ③対象は顧客が他社サービスで使用中の実パスワードで分類B（最厳格）」を説明したうえでCEOが平文保存を再確認・確定。**release-readiness C-3（顧客SNS認証情報の暗号化）は本決定により「対応しない」へ変更が必要** |
| 分類B 平文化後の代替防御 | アクセス制御（RBAC＋Pundit スコープ＋IP許可リスト＋メールOTP）／`Auditable::TRACKED_FIELDS` から除外し値をAuditLogに残さない／`filter_parameter_logging`（`:pass` 等）でログにも残さない／`CsvExportJob::EXPORT_TARGETS` の列許可リストでCSVにも出さない／**DB・バックアップの at-rest 暗号化（R8 で要件化。Q-D-2 で分類Aを平文追認した際の前提条件でもあり、分類B平文化により重要度がさらに上がった）** | 「暗号化列だから自動的に安全」という前提が全面的に無くなったため、上記の各防御が唯一の防御線になる。列を追加・変更する際は都度確認すること |
| 分類A（Customer/Store 本体の PII）の暗号化 | **暗号化しない方針で実装先行**。`customers.name` に index、`email` に UNIQUE index（Devise ログインID）、名前検索は LIKE、pg_bigm 全文検索を前提。**正式決定の記録が無い**（04 R2見直しレビュー残タスク・リスク5「R2着手前に確定が必要」が未消化のまま実装） | `db/schema.rb`、`app/models/customer.rb`（`encrypts` 無し） |
| 分類C（`netmove_member_id` 等）の暗号化 | **未決・平文**。R5（決済）着手前に方針が要る | `customers.netmove_member_id` string(50)、フォームのホワイトリストからも未除外 |
| 監査ログ・ログ出力での PII | 分類B は除外済み。分類A は `AuditLog` に name のみ、`filter_parameters` は email のみ | §1-1 |

### 5-2. 決定待ち事項（決定者 へ提示する選択肢）

**論点 Q-D-1: 分類B（SNS認証情報）を新システムへ運ぶか**（Q-D 原義）

| 案 | 内容 | 影響 |
|---|---|---|
| (i) 運ぶ | R7 ETL で `encrypts` 済み列へモデル経由 load（§4-4） | 業務継続性は高い（GBP/SNS 作業で必要）。漏えい時の影響は暗号化で緩和。鍵管理（credentials）が運用上の単一障害点 |
| (ii) 運ばない | 列は残すが移行対象外。以後は新規入力のみ（または別管理・パスワードマネージャ等へ分離） | 移行マッピング（`legacy-research/11` §4）から8列を除外。既存案件の作業時に旧システム/別管理を参照する運用が必要 |

**論点 Q-D-2: 分類A（Customer/Store 本体 PII）を暗号化するか** — 実装は「しない」で先行。決定記録が必要

| 案 | 内容 | コスト | 検索性・機能への影響 | 備考 |
|---|---|---|---|---|
| **A-1 現状追認**（推奨: 実装と整合） | 分類A は平文のまま。保護はアクセス制御（RBAC・Pundit スコープ・IP許可リスト・OTP）＋監査ログ＋**保存領域の暗号化（DB at-rest / ボリューム暗号化＝インフラ側・R8 で確定）**＋ログフィルタ | 低（追加実装なし。R8 でインフラ側の at-rest 暗号化とバックアップ暗号化を要件化するのみ） | 影響なし（LIKE / pg_bigm・ソート・UNIQUE email・Devise ログイン・CSV・ETL すべて現状どおり） | DB ダンプ・バックアップ流出時は平文。個人情報保護法上「暗号化」は必須要件ではなく安全管理措置の一手段 |
| A-2 選択的暗号化 | 検索キーにしない列（`mobile_phone` `sms_mobile_number` `fax_number` `invoice_phone` `invoice_other_phone` `contact*_dept_phone` 等の連絡先）のみ `encrypts`（非決定的）。`name` / `email` / `phone` / 住所は平文 | 中（対象列の選定・migration不要だが既存データ再暗号化バッチ・spec・CSV/ETL の書き込み経路をモデル経由に統一） | 対象列は等価・部分一致検索・ソート不可。CSVエクスポートは復号して出力（性能は件数規模なら問題なし） | 「電話番号での顧客検索」要件があるなら `phone` は平文維持が前提 |
| A-3 分類A 全面暗号化 | 氏名・カナ・住所・電話・メール全てを `encrypts`。`email` は Devise ログイン用に `deterministic: true, downcase: true`、`name` 等の検索用に別途ブラインドインデックス列（ハッシュ）を追加 | 高（スキーマ追加・検索実装の作り直し・pg_bigm 全文検索と非互換・`customers.name` index の意味消失・監査ログ/通知テンプレの差し込み・R7 ETL 全経路モデル化・鍵ローテーション運用） | 部分一致（LIKE）・pg_bigm・ソート・範囲検索が全滅。決定的暗号化列は等価検索のみ。管理画面の顧客検索 UX が大きく劣化 | 03§2「pg_bigm 全文検索」決定と実質矛盾。採用するなら 03 決定Aの補足改訂が必要 |

**論点 Q-D-3: 分類C（`netmove_member_id` ほか決済系）** — ✅ 2026-08-19 v5 CEO決定: **C-2（平文＋アクセス制御）を採用**

| 案 | 内容 | 影響 |
|---|---|---|
| C-1 `encrypts` deterministic | `netmove_member_id` を決定的暗号化（等価検索・UNIQUE 可能）。R5 の `payment_transactions` 系も同方針 | 等価検索のみで足りる列のため機能影響ほぼ無し。フォームのホワイトリストからも自動除外される（副次効果）|
| **C-2 平文＋アクセス制御（採用）** | 分類A と同じ扱い | 追加コスト無し。カード番号は保持しない前提（ネットムーブ側保持）が崩れないことが条件。アクセス制御（RBAC・Pundit・監査ログ）で保護する |

- 本書の立場: **Q-D-1 が確定するまで、分類Bのカラムは移行 load 対象から保留**とし、
  ETL準備工程（抽出・変換）では他フィールドと分離した中間ファイルに隔離しておく【提案】。
  これにより Q-D-1 の決定がどちらでも手戻りしない。
- Q-D-2 は **A-1（現状追認）を推奨**。理由: 実装・03 決定A（pg_bigm）・R7 ETL 設計と整合し、追加コストが無い。ただし
  R8（release C-5）で「DB/バックアップの at-rest 暗号化」「本番相当データを PII ルール確定前に AWS 等へ置かない」を要件として明文化することを条件とする。
- ~~Q-D-3 は **C-1 を推奨**（コスト小・R5 実装前なら手戻り無し）。~~ → **✅ 2026-08-19 v5 CEO決定: C-2（平文＋アクセス制御）を採用**（推奨のC-1ではなく現状の平文保存を継続する判断）。
- Q-D の決定は本書の改訂トリガー（決定内容に応じて §4-4 に分類Bの移行手順を確定し、§1 表の保護状態列を更新する）。

---

## 6. 違反時・事故時の対応【提案】

- 実データをコミットしてしまった場合: **push 前なら**直ちにコミットを取り消す
  （※ git 書込は `scripts/ai-git.sh` 経由のロック運用。取り消しも同ゲートを通す）。
  **push 後は履歴に残るため**、秘書経由で決定者へ即報告し、履歴スクラブ（filter-repo等）と
  流出した分類B認証情報のパスワード変更依頼（発注元経由）までをワンセットで実施する。
- 外部サービスへ誤投入した場合: 投入先・範囲を記録して決定者へ報告。分類Bを含む場合は
  該当アカウントのパスワード変更依頼を最優先とする。
- Rails credentials（`config/master.key` / `RAILS_MASTER_KEY`）が流出した場合: `encrypts` 列の暗号化が無効化されるのと同義のため、
  鍵ローテーション（`active_record_encryption` の `previous` 鍵設定 → 再暗号化）と上記報告をワンセットで実施する【提案・R8 運用手順に組み込む】。

---

## 7. 完了条件 — 何をもって「Q-A 解消」とするか

`development-plan-review-20260726.md` §3-2 の指摘（「担当・完了条件を持つタスクが無い」）に対応し、
以下の全条件を満たした時点で Q-A を解消（クローズ）とする:

| # | 条件 | 状態（2026-08-19） |
|---|---|---|
| 1 | 本ルールの決定者承認（ドラフト→確定） | ⬜ 未（本書がそのドラフト） |
| 2 | 担当者の割当（ルールの維持責任者・違反時の一次対応者） | ⬜ 未 — **（担当: ＿＿＿ ← 決定者判断のプレースホルダ）** |
| 3 | 機械的担保の実装確認: 親 `.gitignore` の `private/`（✅ 2026-08-19 再確認済み）＋ 本リポジトリの `/storage/*`（✅ Rails 標準で ignore）＋ `requirements/input/`（⬜ brige-crm には未作成・R7 で追加）＋ §2-3 の追加パターン（⬜提案・未実装） | 一部済 |
| 4 | 既存文書への反映: `development-plan.md` Q-A 行を「本書参照・確定」に更新、`release-readiness.md` C-5 / G-8 の状態欄を本書参照へ更新、`04-rails-implementation-plan.md` R2見直しレビュー残タスク「PII方針（Q-D）」・リスク5 の消し込み | ⬜ 未 |
| 5 | 発注元への提起（`business-flow-analysis.md` §0 の「資料の共有範囲見直し・記載例の匿名化」）の実施 or 実施不要の判断 | ⬜ 未（外部アクションのため承認パイプライン経由） |

> Q-D（§5）は別Issueとして残る。Q-A の完了に Q-D の決定は**含めない**
> （§5 の保留ルールで手戻りなく待てるため）。**Q-D-3（分類C）は 2026-08-19・v5 で決定済み（C-2 平文＋アクセス制御）**。
> 残る **Q-D-2（分類A方針）は運用開始（R8）前、Q-D-1（分類B移行）は R7 着手前**にそれぞれ決定が必要。

---

## 8. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-26 | 初版ドラフト。3分類定義・保管/使用/移行ルール・Q-D接続・完了条件を起案（決定者確認待ち） |
| 2026-08-19 | Rails版改訂。パス・クラス名を brige-crm 実装へ書き換え（`app/models/concerns/auditable.rb`・`encrypts`・`filter_parameter_logging`・`storage/`）。§1 に Rails版保存先と保護状態、§1-1 に横断的保護機構（実装済み）を追加。§5 を「Q-D の現状と決定待ち事項」に改め、Q-D-1〜3 の選択肢とコスト・検索性への影響を整理（A-1 現状追認／C-1 推奨）。§4-4 に暗号化列の load 注意を追加 |
