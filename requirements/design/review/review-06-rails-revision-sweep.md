# review-06: 設計ドキュメント一式の Rails版改訂（実装突合）サマリ集約

- 実施日: 2026-08-19
- 目的: review-05 で棚卸しした旧Laravel設計ドキュメント（`requirements/design/` 配下 + `development-plan.md`）を、brige-crm（Rails 8.1）の**現行実装（db/schema.rb・app/）と 03/04 の決定**に合わせて全面改訂した際の、各担当エージェントのサマリを集約したもの
- 方法: 9グループ（A〜I）に分け並列エージェントで改訂。各ドキュメントに「Rails版改訂ヘッダ」「実装済み／差分／未実装（Rx）」注記を付与し、必要に応じて「実装突合表」を追加。**業務要件・決定事項・未決論点・履歴は保持**し、Laravel固有記述のみ Rails 等価物へ置換
- リネーム: `contract-confirmation-docs.md` → `contract-confirmation-docs.md`、`notification-matrix.md` → `notification-matrix.md`（相互参照は一括置換済み）
- **04-rails-implementation-plan.md への反映は本サマリを一次情報として実施済み（04 v4）**。本ファイルは判断根拠の保存が目的（詳細は各設計書の突合表を参照）

| グループ | 対象ファイル | フェーズ |
|---|---|---|
| A | basic-design.md | R0〜R5 |
| B | Column.md | R1/R2（+R5/R6 未実装テーブル） |
| C | payment-integration.md / netmove-card-migration.md / contract-confirmation-docs.md | R5 |
| D | board-implementation-options.md / notification-matrix.md / status-naming-analysis.md | R4 / Q-B |
| E | form-template-mapping.md / pii-handling-rules.md | R3 / Q-D |
| F | customer-merge-design.md / export-profile-design.md / business-flow-analysis.md | R6 |
| G | release-readiness.md / development-plan.md | R8 / 全体 |
| H | legacy-research/00〜08 | R7 |
| I | legacy-research/09〜15 / name-matching-process.md | R7 |

---


<!-- ===== summary-A-basic-design ===== -->

## サマリ A: `requirements/design/basic-design.md`（Rails版改訂 2026-08-19）

対象: `/home/fujisawa/project/ai-auto-company/projects/brige-crm/requirements/design/basic-design.md`（1136行 → 1427行。18章構成・項番は全て維持。§2-4 と付録A を追加）

## 主な改訂内容

- 冒頭に改訂ヘッダ（Rails版改訂日・元ファイル・フェーズ対応 §1-5/§15-18=R0〜R4、§6-14=R5）と「本書の位置づけ」を追加。凡例に「実装状況ラベル（✅実装済み / ⚠️差分 / ⏳未実装）」と「認証・認可の全体像（admin/form/mypage の3系統 × Devise+メールOTP / 独自セッション+OTP / Customer+OTP、RBAC+Pundit）」の表を追加。
- §1 ユーザ管理: ログイン系統を「2系統」→「3系統（＋顧客マイページ）」に整理。`users.agency_group_id / agency_id` 直管理・排他制約、組み込み4ロール（`admin` / `実務運用者` / `代理店グループ用` / `代理店用`）、CSV一括アップロード（`UserCsvImportJob`）を実装済みとして注記。旧「ユーザ無効化 未実装」は `users.is_active` + `active_for_authentication?` で実装済みに更新。
- §2 ログイン管理: Devise recoverable / timeoutable / lockable、rack-attack、AuthAuditable を実装済みとして注記。営業担当者はパスワード無し（OTP）・Customer は recoverable なしを差分として明記。**§2-4「二要素認証（メールOTP）・IP許可リスト」を新設**（Q-19/Q-23/P4-17。`OtpAuthenticatable` の3モデル横展開・`IpAllowlistEntry` フェイルセーフ）。
- §3 権限管理: 最大の書き換え。`organizations` + Nested Set（kalnoy/nestedset）前提の「既存リポジトリへの追加作業①〜⑥」を、現行 `db/schema.rb`（`agency_groups` / `agencies` / `contract_conditions` / `sales_representatives` / `orders.contract_condition_id` / `users.agency_*_id`）の実装スキーマ表に全面置換。2層認可（エンドポイントRBAC + Pundit `AgencyScoped`）と `strip_ownership_params!` を記述。T-2（sales_rep_code グローバルユニーク）・T-3（契約条件は受注側）是正済みを明記。旧「現行実装との差異あり（2026-07-27）」注記は解消済みに更新。
- §4 顧客一覧: `jasmin_customers` → `customers`（決定D。将来分離は namespace）。`SequenceCounter` 採番、pagy、CSV非同期エクスポート（`CsvExport` / `CsvExportJob`）を注記。統合ビュー・名寄せは R6 と明記。
- §5 顧客詳細: 「フィールド定義待ち」→ Column.md §8 で確定・R2実装済みに更新。PII方針（Q-D）の実装状況、退会（`withdrawn`）の実装状況を注記。
- §6 申込登録: 想定フローの各段階に R3 実装済み / R5 未実装を付記。R3 実装（`Form::SessionsController` / `Form::OtpsController` / `FormTemplate` 系 / `Application` token 進行 / `Form::ApplicationSubmissionService` 一括生成 / `Form::DynamicFormValidator` / メール通知）を詳述。
- §7 決済連携: 未実装（R5）。Rails版実装方針（`PaymentTransaction` + `PaymentTransactionLog`、7状態の手実装状態機械・mark/confirm 分離、Solid Queue 専用キュー＋自動リトライ無効、`form` 名前空間の ret_url 受け口・セッション非依存・unknown 留置、`ReconciliationSource`、request spec 必須、D-P8 CSV の実装先確定）を `payment-integration.md` §4〜§6 に整合させて追記。削除済み `impl-plans/P3-2-payment.md` 参照を差し替え。
- §8〜§14: 全て「未実装（R5）」と明記し Rails版実装方針を追加。§8 `InputCheckRule` 案と `FormField.validation_rules` の役割分担、§9〜§12 は「契約ステータス」1本（Q-B 案A）に統合した手実装状態機械（`orders.contract_status` + `contract_reviews`）・状態機械→重説の実装順、§11 `KeywordSuggestionService`（保存先 `order_work_details.keyword_industry_main / sub1〜4` は実装済み）、§13/§14 `ContractDocument` + Active Storage + PDF gem 要選定・版数管理・`ContractMailer`。
- §15 案件一覧: Bridge/BridgePlus は単一 `orders`。検索は `q`+`status` のみ（メール検索は R6）。手動作成が存在する点を差分。
- §16 監査ログ: `AuditLog` / `Auditable::TRACKED_FIELDS` / `AuthAuditable` を実装済みとして詳述。ログアウト未記録・汎用検索画面未実装（`login_histories` は AuditLog 絞込ビュー）を差分。
- §17 問い合わせ管理: R4 実装（Inquiry 4カテゴリ統合・`InquiryStatus` マスタ・`RecipientResolver` / `InquiryRecipientRoute` / `InquiryMessageMailJob` / `SystemNotification` + Solid Cable）を注記。顧客側公開フォーム・メールリンク返信・返信テンプレ選択UIは未実装。
- §18 選択肢マスタ: `parent_id` 方式（closure_tree 不採用）・循環参照/グループ越境防止を実装済みとして注記。`*_id + *_label` スナップショット構造は未採用（文字列保持）を差分。
- 末尾に「付録A. Rails版改訂サマリ」（章別の実装状況一覧・関連ドキュメント・削除済みファイル一覧）を追加。

## 現行実装との差分・未実装事項（フェーズ付き）

| 章 | 差分 / 未実装 | フェーズ |
|---|---|---|
| §1-1 | 「所属部署」カラム・マスタ無し。1組織=1アカウントは強制していない | R6 判断 |
| §1-2 | ユーザ一覧の検索条件（氏名/メール/権限/所属/状態）・pagy 未実装 | R6 |
| §1-1 | ユーザCSVインポート結果の履歴永続化・UI 未実装 | R6（04 R1見直し残） |
| §2-1 | 営業担当者はパスワード無し → 再設定対象外。Customer は recoverable なし | 仕様追従 / R6 |
| §2-2 | session `expire_after`・`force_ssl`・form ログイン時の session ID 再生成 未対応 | R8 |
| §2-3 | 代理店CD＋営業担当者CD 総当たり対策の専用スロットル未設定（OTP上限＋rack-attack のみ） | R8 |
| §2-4 | マイページ側は IP許可リストによる OTP 免除を適用していない（意図的） | 要確認 |
| §3-1 | 「実務運用者: 一部制限あり」の業務定義未確定（実装は全件参照＋既定マトリクス） | 要確認 |
| §3-1 | 販売許可（agency_products / agency_group_products）の管理UI 未実装 | R6 |
| §3-1 | `agencies` に住所・電話カラム無し（Q-移7） | R7 |
| §4 | 商材横断統合ビュー・名寄せ 未実装 | R6 |
| §4-2 | 顧客検索は `q`（顧客番号・氏名）のみ。代理店/ステータス/期間 未実装 | R6 |
| §5-1 | 詳細画面のタブ分割 未実装 | R6 / R5 |
| §5-2 | 代理店ユーザは管理画面から新規顧客作成不可（`create?` = staff のみ）。Q-B 呼称（customer_statuses=「申込ステータス」）未統一 | 要確認 / R5前 |
| §5-3 | 退会専用アクション無し。一覧が退会済みを既定除外していない。退会時の orders/stores 連動未定 | R6 |
| §6 | クレカ登録・確認書PDF添付・重説チェック・手書き署名・契約確認メール 未実装。顧客端末への URL 送付経路無し。form-template-mapping 155項目突合未実施 | R5 / R3要確認 |
| §7 | 決済連携一式 未実装（payment_transactions 未作成） | R5 |
| §8 | 入力チェック設定 未実装 | R5 |
| §9〜12 | 契約ワークフロー状態機械・差戻し・確認コール操作・キーワード自動選定 未実装（記録列のみ存在） | R5 |
| §13〜14 | 契約書PDF生成・版数管理・送付・参照 未実装。PDF gem 未選定 | R5 |
| §15-1 | 顧客メールアドレスによる案件検索 未実装 | R6 |
| §15-2 | 案件の手動新規作成が存在（旧記述より広い）。ステータス遷移バリデーション無し | 要確認 / R6 |
| §16-1 | ログアウトイベント未記録。form の CD照合失敗未記録。監査ログ5年保存の prune 未実装 | R6 / R8 |
| §16-2 | 汎用監査ログ検索画面 未実装（ログイン履歴200件固定のみ） | R6 |
| §17-1 | 顧客側公開問い合わせフォーム・メールリンクからの顧客返信 未実装 | R6 |
| §17-2 | 問い合わせ検索は category のみ | R6 |
| §17-3 | Inquiry の edit/update/destroy ルート無し（意図的） | 要確認 |
| §17-4 | 返信テンプレ選択UI・差し込み変数・FAQ 12カテゴリ 未実装 | R4後続 / R6 / R7（要確認） |
| §18-1 | フォーム側で `OptionGroup.is_active` を参照しているか要点検 | R5 |
| §18-3 | `*_id + *_label` スナップショット構造は未採用（文字列保持） | R5 / R7 判断 |

## 04-rails-implementation-plan.md へ反映すべき新規タスク／変更

| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R5 | 高 | §9〜§12 のステータスを「契約ステータス」1本に統合した状態機械（`orders.contract_status` 拡張 or `contract_workflow_states` マスタ）+ `contract_reviews`（遷移履歴・差戻し理由/対象項目/コメント/差戻し先）を R5 本文の「契約ワークフロー状態機械」の具体設計として明記 | basic-design §9〜§12 |
| R5 | 高 | `ContractDocument`（order_id / version / document_type / snapshot / is_latest）+ Active Storage + PDF gem 選定（grover/ferrum vs prawn）+ `ContractMailer` を R5 タスクに追加。手書き署名は Active Storage 添付 | §13〜§14 |
| R5 | 高 | 決済 ret_url 受け口を `form` 名前空間（例 `Form::PaymentCallbacksController`）に置き、セッション非依存で `PaymentTransaction` を復元する方針を R5 本文に追記。決済ジョブの専用キュー名と `retry_on` 禁止を明文化 | §7 |
| R5 | 中 | 入力チェック設定 = `InputCheckRule` モデル + `InputCheckRuleEvaluator`（申込フォームと管理画面編集の共通呼び出し）。「3段階必須」を `FormField.requirement_level` か `InputCheckRule.severity` のどちらで持つか着手時に決定 | §8 |
| R5 | 中 | キーワード自動選定 = `KeywordSuggestionService` + 申込フォームの Stimulus 連携（保存先は既存 `order_work_details.keyword_*`） | §11 |
| R5 | 中 | 申込フォームの「顧客端末への URL 送付」経路（`Application#token` 付き URL の別セッション許可＋有効期限）を R5 で要否確定 | §6 未確定① |
| R5前 | 中 | §18-1: フォーム側の選択肢参照が `OptionGroup.is_active` も見ているか点検 | §18-1 |
| R6 | 中 | 一覧検索強化を一括タスク化: ユーザ一覧（§1-2）・顧客一覧（§4-2: 代理店/ステータス/期間、既定=退会済み除外）・案件一覧（§15-1: 顧客メール）・問い合わせ一覧（§17-2）。pg_bigm フリー検索の適用も検討 | §1-2 / §4-2 / §5-3 / §15-1 / §17-2 |
| R6 | 中 | 汎用監査ログ検索画面 `Admin::AuditLogsController`（ユーザ/操作種別/対象/実行日時）+ `logout` イベント記録の追加 | §16 |
| R6 | 中 | 顧客側問い合わせ導線（マイページにスレッド表示・返信フォーム、メールリンク → マイページログイン → 返信）| §17-1 |
| R6 | 低 | 顧客詳細のタブ分割（Turbo Frame）。退会専用アクションと退会時の orders/stores 連動ルール（ステータス遷移バリデーションと同時に設計） | §5-1 / §5-3 |
| R6 | 低 | 「所属部署」の要否判断（社内ユーザ）。Customer 向けパスワード再設定（recoverable）の要否 | §1-1 / §2-1 |
| R8 | 中 | form のセッション ID 再生成・`expire_after`・`force_ssl`（既存 R3 見直し残タスクを R8 に明示）、代理店CD＋営業担当者CD 総当たりのスロットル、form の CD照合失敗の監査記録、監査ログ5年保存の prune 方針 | §2-2 / §2-3 / §16-1 |
| R7 | 低 | §18-3: `*_id + *_label` スナップショット構造の要否をマッピング設計で判断 | §18-3 |

## 決定者/業務側の確認が必要な未決論点

1. **実務運用者ロールの「一部制限あり」の具体定義**（§3-1）。現状は社内ユーザとして全件参照＋既定マトリクス。運用前に確定要。
2. **代理店ユーザに管理画面からの新規顧客作成を許可するか**（§5-2。現状は staff のみ。新規顧客は申込フォーム経由が前提）。
3. **Q-B ステータス呼称**: `customer_statuses` を「申込ステータス」に統一するか、R5 の契約ワークフローを「契約ステータス」と呼ぶか（§5-2 / §9。04 次のアクション5 と同件）。
4. **退会（利用停止）時の紐づく受注・店舗・マイページの扱い**（§5-3）。
5. **申込登録の未確定①〜⑤**（顧客入力端末 / 支払方法種類 / 顧客重複時方針 / 重説の実施者・タイミング / 手書き署名の取得手段）と、それに連なる R5 着手前ブロッカー Q-25〜27・Q-35〜39・E6（§6 / §7）。
6. **問い合わせ返信テンプレート（FAQ 318件・12カテゴリ）の実装要否とフェーズ**（§17-4。04 次のアクション5 と同件）。
7. **顧客マイページからの契約書参照・ダウンロード要否**（§14）と **マイページ側の IP許可リスト OTP 免除要否**（§2-4）。
8. **BridgePlus 代理店のログインメールを通知先 `agencies.email_1〜5` と兼用するか**（§3-1。旧来からの未確認事項。現状は独立）。
9. **Inquiry の訂正 UI（edit/destroy）要否**（§17-3。現状は履歴改ざん防止で意図的に無し）。
10. **PII 分類A（顧客本体）を暗号化しない方針の正式決定・文書化**（§5。実装先行・記録後追い）。

---

<!-- ===== summary-B-column ===== -->

## サマリ B: `requirements/design/Column.md`（スキーマ設計の正）Rails版改訂 — 2026-08-19

対象: `/home/fujisawa/project/ai-auto-company/projects/brige-crm/requirements/design/Column.md`（999行 → 1,921行）。`db/schema.rb`（version 2026_08_16_150002）を正として全11テーブル・全カラムを機械突合（Pythonスクリプト）し、§1〜§11 の全列が実装と一致する状態にした（相違は「実装を正」として追従、業務上の意味が変わるものは「要確認」明記）。

## 主な改訂内容
- 冒頭に改訂ヘッダ（フェーズ対応: §1〜11 = R1/R2、§12 = R0〜R4 追加分、§13 = R5/R6 未実装）と「以後スキーマの正は db/schema.rb」の宣言を追加。目次を §0〜§14 に拡張、章番号 §1〜§11 は維持。
- 新設 **§0 Rails版 共通規約**: UUID主キー（gen_random_uuid）、timestamps NOT NULL、`created_by_id`/`updated_by_id`（TracksUser）、FK on_delete、ステータスはマスタ code 参照（DB FK なし・モデル検証・SystemManagedStatus）、採番は `sequence_counters`（count()+1 不採用）、PII 分類B の ActiveRecord::Encryption、Auditable/AuthAuditable、3認証主体＋メールOTP、polymorphic 規約、決定D（jasmin_ 除去）。
- 型表記を MySQL（VARCHAR/UNSIGNED/ENUM/TIMESTAMP）→ Rails 型（string(n)/integer/date/datetime/text/boolean/uuid/jsonb）に全面置換。凡例に ENC（暗号化）を追加。
- テーブル名・モデル名の読み替え: `jasmin_customers/stores/orders/order_work_details` → `customers/stores/orders/order_work_details`、`jasmin_customer_id` 等 → `customer_id` 等（見出しに旧名を併記）。
- §1〜§11 各節に「実装状況」「実装との差分」を明記し、リレーション表を実装の関連（dependent / on_delete / has_many through 等）に更新。
- §4 plans: `initial_fee`/`payment_method`/`plus_flag` を取り消し線＋移設先（product_initial_fees / orders.payment_method / product_options+order_options）、`sort_order` 追加、`contract_unit`/`initial_construction` は未実装・要確認。
- §5 agency_products: 複合PK → `id uuid`＋unique index＋timestamps。管理UI未実装を明記。
- §7 sales_representatives: `email`/`otp_*` 4列（R3 メールOTP）追加、T-2 グローバルユニーク踏襲、長さ制限なし（軽微・要確認）。
- §8 customers: `contract_condition_id` を取り消し線（T-3 是正で orders 側）、`phone_number` → `phone` 確定、Devise 4列＋OTP 3列（R4）追加、`email` UQ、`status` 既定 `applied`（customer_statuses.code、既定8集合を記載）、新規採番 `C-%06d`。
- §10 orders: `contract_condition_id`（NOT NULL, T-3）/ `payment_method` / `product_initial_fee_id` 追加、`status` NOT NULL 既定 `0:受注`（order_statuses.code）、`billing_password` text・ENC、新規採番 `ORD{YYYY}{%04d}`（年別キー）。
- §11 order_work_details: ID/PASS 8列を text・ENC。
- 新設 **§12（実装のみに存在する 37 テーブル）**: users / system_permissions / system_roles / system_role_permissions / user_system_roles / ip_allowlist_entries / audit_logs / customer_statuses / order_statuses / option_groups / option_values / production_companies / sales_materials / sequence_counters / product_initial_fees / product_options / order_options / agency_group_products / form_templates / form_steps / form_fields / applications / inquiries / inquiry_messages / inquiry_message_recipients / inquiry_statuses / inquiry_recipient_routes / recipient_groups / recipient_group_members / notification_templates / notifications / notification_recipients / system_notifications / csv_exports / active_storage_*。列定義は schema.rb から機械抽出（型・NULL・既定値・FK(on_delete)・UQ/IDX）し、説明はモデル注釈・冒頭コメントから記述。
- 新設 **§13 未実装テーブル（R5/R6）**: payment_transactions / payment_transaction_logs / 契約書・署名 / 顧客側カード情報 / customer_merges・customer_merge_keys / 集計・遅延検知 / 未収情報 / 商材別納品日 / export_profiles / order_histories / agency_emails / inquiry_message_production_companies（定義の所在・フェーズ・備考）。
- 新設 **§14 実装突合表（2026-08-19）**: §1〜11 テーブル別の一致/差分/未実装、実装のみのテーブル一覧、設計方針記述の更新一覧（採番・T-2・T-3・ステータス・PII・認証・監査・ツリー）。

## 現行実装との差分・未実装事項（フェーズ付き）
- 一致（共通差分のみ）: agencies / products / contract_conditions / stores。
- 差分（実装を正として追従済み）: agency_groups（service_type IDX 未作成）、plans（列分解）、agency_products（PK方式）、sales_representatives（OTP列追加・長さ制限なし）、customers（phone・Devise/OTP・email UQ・status code・contract_condition_id 撤去）、orders（contract_condition_id/payment_method/product_initial_fee_id 追加・status NOT NULL・billing_password ENC）、order_work_details（8列 ENC）。
- 未実装（R5）: payment_transactions / payment_transaction_logs、契約書PDF・版数・署名、顧客側カード情報列（netmove 会員IDで代替前提）。
- 未実装（R6）: customer_merges / customer_merge_keys、集計・遅延検知・自動キャンセル、CSV エクスポートプロファイル、ステータス遷移バリデーション、Store の一覧検索・CSV エクスポート。
- 未実装（要否未定）: `plans.contract_unit` / `initial_construction`、未収情報フィールド、商材別納品日（G-1）、agency_products / agency_group_products の管理UI、sales_materials の実ファイルアップロード（Active Storage 化）、inquiry_message_production_companies。

## 04-rails-implementation-plan.md へ反映すべき新規タスク／変更
| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R2 追加 | 中 | `plans.contract_unit` / `initial_construction` の要否確定（未実装のまま R5 契約フローへ持ち越すか、R2 で列追加するか） | Column.md §4, §14-1 |
| R2 追加 | 中 | `customers.email` unique index の業務妥当性確認（同一メールの複数顧客登録の有無）。NG なら認証キーを別列に | Column.md §8 |
| R2 追加 | 低 | `sales_representatives.sales_rep_code` / `name` / `pdf_*` の長さ制限（旧 VARCHAR(50)/(100)）をモデル validation で追加するか判断 | Column.md §7 |
| R2 追加 | 低 | `agency_groups.service_type` インデックス要否 | Column.md §1 |
| R3/R7 | 中 | 新規採番形式の業務確定: `customer_number` = `C-%06d`、`order_number` = `ORD{YYYY}{%04d}`（旧 FTW/JET・BP/BR prefix との共存方針）。R7 移行データと衝突しないことの確認 | Column.md §8, §10, §12-5 |
| R3 | 低 | seeds / FactoryBot の営業担当者コードを 6 桁数値体系に揃える（旧 SampleDataSeeder メモの Rails 版） | Column.md §7 |
| R4 追加 | 低 | `sales_representatives.email` を運用上必須にする（NULL だと OTP ログイン不可）→ validation 追加要否 | Column.md §7 |
| R5 | 高 | R5 実装時に payment_transactions / payment_transaction_logs / 契約書・署名テーブルの列定義を Column.md §13 → 本文へ昇格させる（Column.md を schema.rb 追従で更新するタスクを R5 完了条件に含める） | Column.md §13 |
| R6 | 中 | 同上（customer_merges / customer_merge_keys / export_profiles） | Column.md §13 |
| R7 | 中 | `orders.status` の旧コード体系（BridgePlus「10:作業進行中」/ Bridge「100:100:CLOSE」）を order_statuses へ投入する際の正規化方針確定 | Column.md §9, §10 |
| 横断 | 中 | 「Column.md は schema.rb に追従」の運用ルール化（マイグレーション追加時に Column.md 更新を PR チェック項目に） | Column.md 冒頭 |

## 決定者/業務側の確認が必要な未決論点
1. **顧客メールアドレスの一意制約**（customers.email UQ）— 同一メールで複数契約者を登録する業務があるか。
2. **新規採番の番号体系** — 顧客 `C-000001` / 案件 `ORD20260001` で良いか、旧 `FTW/JET`・`BP/BR` prefix を継続するか。
3. **プラン属性の扱い** — 契約単位・初期構築フラグ（旧 plans.contract_unit / initial_construction）は業務上必要か（必要なら R5 で追加）。
4. **顧客側カード情報**（card_brand / credit_reference_number / order_code / card_changed_at）— 非保持非通過方針のもと列として持たなくてよいか（ネットムーブ会員IDで代替）。
5. **未収情報フィールド**（未回収額等）の要否とフェーズ（R2 追加 or R6）。
6. **分類A PII（氏名・電話・メール等）を暗号化しない方針**の正式決定（実装先行・決定記録未了。pii-handling-rules.md）。
7. **販売許可（agency_products / agency_group_products）の管理UI** を R2 追加で入れるか。
8. **旧 order status コード体系の正規化**（R7）と **ステータス呼称統一（申込ステータス）** の実装完了時期（R5 着手前推奨）。

---

<!-- ===== summary-C-payment ===== -->

## サマリ C（R5 契約フロー・決済領域）— Rails版改訂 2026-08-19

担当: `requirements/design/payment-integration.md` / `netmove-card-migration.md` / `contract-confirmation-docs.md`（3ファイルのみ編集。git 操作なし）
参照（読み取りのみ）: 03§2/§3/§5/§8-2、04 R5節・R5着手前チェックリスト、review-05 §1-1、`legacy-research/02-payment-netmove.md`、`db/schema.rb`、`config/queue.yml`、`config/routes.rb`、`app/controllers/application_controller.rb`、`app/services/system_permission_sync_service.rb`、`app/models/concerns/auditable.rb`、`app/services/form/application_submission_service.rb`、`app/models/notification_template.rb`

---

## 1. `payment-integration.md`（306行 → 489行）

### 主な改訂内容
- 改訂ヘッダ追加（フェーズ対応 R5、突合日 2026-08-19、実装済み/未実装の要約）。章番号 0〜9 は維持。
- §2-2: 現行 R3 実装（`Form::ApplicationsController#submit` → `Form::ApplicationSubmissionService` が Customer/Store/Order を1トランザクションで作成）を踏まえ、決済ステップは **Order 作成後に差し込む** ことを明記。
- §2-3: 実装状況突合表を新設（`customers.netmove_member_id`/`netmove_registered_at`・`orders.payment_method`/`finance_*`/`bundled_billing`/`bundle_target_order_number`・`customers.consolidated_billing`/`sms_mobile_number`・`SequenceCounter`・`Auditable`・`ActiveRecord::Encryption` = 実装済み／`payment_transactions`・決済キュー・Service・ret_url 受け口 = 未実装 R5）。`orders.member_id`（会員管理ID）はネットムーブ会員IDと別物と注記。
- §3 D-P8/D-P10/D-P12 に Rails 版の実装状況を付記（D-P12②の管理画面編集は permit 済みで実質実装済み、①のフォーム分岐は R5）。
- §4-2: Horizon/`$tries=1` → **Solid Queue 決済専用ワーカー（`queues: payments`, threads 1）+ `queue_as :payments` + `retry_on` 禁止 + `discard_on ActiveJob::DeserializationError` のみ + `limits_concurrency`（jutyu_cd キー）+ `lock_version`** に書き換え。
- §4-3: `Payment::ReconciliationSource` duck type（ManualCsv / 将来 Webhook・InquiryApi）、rack-attack で送信元IP制限。
- §4-4: **`PaymentTransaction` 手実装状態機械のコード案**（`STATUSES` / `NETMOVE_STATE_MAP` / `TRANSITIONS` 遷移表 / `mark_*` と `confirm_*` の分離 / unknown からは confirm のみ / `with_lock`）。AASM 不採用の理由を明記。
- §4-5: 監査を **二層**に整理 — `payment_transaction_logs`（通信ログ。ret_url はログインユーザ無し＝`audit_logs.user_id NOT NULL` のため AuditLog に載せられない）＋ `Auditable`/`AuditLog`（管理者操作。TRACKED_FIELDS 宣言）。`Payment::ParamMasker` + `config.filter_parameters`。
- §4-7: 3DS 項目の転用元カラム（`customers.email`/`sms_mobile_number`/`mobile_phone`/`prefecture`）と `Payment::CardholderInfoBuilder`。
- §4-8: 請求用受注データCSVは **R4 実装済み `CsvExportJob::EXPORT_TARGETS` に `"BillingOrder"` プロファイルを1エントリ追加して R5 で先行、R6 の P4-12 汎用化時に移す** 案を提示。
- §4-9: `VerifyCsrfToken` → `skip_forgery_protection` + `skip_before_action :authenticate_user!, :require_form_sales_representative!`、セッション不参照。**`Payment::CheckCode`（`OpenSSL::HMAC.hexdigest("SHA256", …)` + `ActiveSupport::SecurityUtils.secure_compare`、送信/検証で別メソッド、鍵は credentials/ENV をサイトコード単位で `Payment::Config` 経由）** のコード案。
- **§4-10 新設: Rails版アプリ構造・配置**。03§3 の section 設計に整合させ、
  - 決済開始 = `Form::PaymentsController`（form / FormAuthenticatable）
  - **ret_url/cancel_url 受け口 = `Form::PaymentReturnsController`（form section 推奨）**: `form/` は RBAC 完全スキップ済み（03§8-2 決定b）で `SystemPermissionSyncService`/`skip_system_permission_authorization?` を改修せずに済み、認証スキップが1コントローラに閉じる。代替案 `webhooks/` 名前空間は RBAC 基盤2箇所（`EXCLUDED_CONTROLLER_PREFIXES` + skip 判定）の改修が必要なため Webhook 提供時に再検討（要確認）。
  - 管理画面 = `Admin::PaymentTransactionsController` + `Admin::PaymentReconciliationsController` + **`PaymentTransactionPolicy`（親 Order の代理店スコープ継承）**
  - カード変更導線 = mypage（候補A）/ admin メールリンク（候補B）— 未決
  - Service 群 `app/services/payment/*`（Config / CheckCode / JutyuCodeGenerator / MemberIdAllocator / CardholderInfoBuilder / CheckoutSession / ReturnHandler / ParamMasker / OrderStatusSyncService / ReconciliationSource）、ジョブ（`Payment::ReconciliationJob` 等）、`PaymentMailer`
- §5: `payment_transactions` に `customer_id`（論点9の帰結）/ `site_code` / `netmove_member_id`（送信スナップショット）/ `last_transition_source` / `expires_at` / `canceled_at` 等 / `lock_version` を追加、`jutyu_cd` は `limit: 12` unique + `SequenceCounter` 採番。`payment_transaction_logs` の列を具体化。
- §6: 各タスクに「Rails版の状態」列を追加（P3-2-j のテスト内容を model/request/job spec で具体化、WebMock スタブ・ダミー鍵）。
- §7: R-12（ret_url の認証スキップによる攻撃面）を追加。
- §8: **04 Q-25〜27・Q-35〜39 との対応列を追加**（論点9→Q-36、I-19/D-1→Q-37、I-18/C-1〜4/R-8→Q-38、R-6/P3-2-i→Q-39）。テスト用マーチャント情報（サイトコード S084 等）・依頼番号はそのまま保持。
- §9 変更履歴に 2026-08-19 行を追加。

### 現行実装との差分・未実装事項
- 実装済み（R2）: `customers.netmove_member_id`/`netmove_registered_at`、`orders.payment_method`/`payment_collected_at`/`payment_doc_confirmed_at`/`finance_*`/`bundled_billing`/`bundle_target_order_number`、`customers.consolidated_billing`/`sms_mobile_number`、`SequenceCounter`、`Auditable`/`AuditLog`、`ActiveRecord::Encryption`。
- 未実装（R5）: `payment_transactions`/`payment_transaction_logs`、状態機械、`Payment::*` Service、決済専用キュー、ret_url 受け口、管理画面/Policy、日次突合、決済状態→業務ステータス連動、3DS 項目送信、フォームでの3択分岐（D-P12①）、請求用CSVプロファイル。
- 実装が設計と異なる/注意: `audit_logs.user_id NOT NULL` → 通信ログは AuditLog に載せられない（専用テーブル必須）。`SystemPermissionSyncService#section_for` は form/mypage 以外を admin 扱い（フェイルクローズ）→ 新名前空間追加にはコスト。

## 2. `netmove-card-migration.md`（251行 → 288行）

### 主な改訂内容
- 改訂ヘッダ（フェーズ対応 R5＋R7、保持先カラム R2 実装済み・ETL/採番/導線は未実装）。
- `jasmin_customers` → `customers`（決定D）。§0 サマリ表に「新システム側の受け皿」行を追加。
- §2-2 1桁問題に 04 Q-37 との対応と設計上の回避策（受注コード下位7桁を `SequenceCounter` 独立キーで採番）を付記。
- §2-5 HMAC キーの置き場（credentials/ENV、`Payment::Config` 経由。値は書かない）。
- §3 シナリオA: ETL の実装形（`lib/tasks/etl/netmove_member_ids.rake`、`customer_number` で突合、検証レポート、PII は private 配下のみ）＝R7。会員ID採番 = `Payment::MemberIdAllocator`（既存優先/`SequenceCounter` 採番、初期値は取り込み後に手動シード）。シナリオB: 自社開発時の候補 = `Mypage::CardsController`。共通: カード変更導線の section 未決（mypage/admin）。
- §6 実装への反映: 各項目に Rails 実装形・フェーズを併記。**追加項目 5**: `Auditable TRACKED_FIELDS["Customer"]` に `netmove_member_id`/`netmove_registered_at` を追加（現行 R2 では会員IDの変更履歴が監査ログに残らない）。項目2に **`customers.netmove_member_id` の部分ユニークインデックス追加**（現行 schema に無い）。
- 業務判断・件数集計・証拠の連鎖・質問リスト B-3a〜e/D-5/S-1改〜S-7新は無変更。§7 変更履歴に追加。

### 現行実装との差分・未実装事項
- 実装済み（R2）: 保持先2カラム、`SequenceCounter`。
- 未実装: 取り込みETL（R7）、`MemberIdAllocator`/`JutyuCodeGenerator`（R5）、member-modify 導線（R5 スコープ境界のみ）、`netmove_member_id` unique index（R5 migration）、Auditable 追跡（R5）。

## 3. `contract-confirmation-docs.md`（197行 → 245行）

### 主な改訂内容
- 改訂ヘッダ（フェーズ対応 R5、重説/文書/確認書は全て未実装、隣接実装 R3 applications・R4 通知基盤・R0 監査・R2 同意カラム）。
- §1 フロー図に R3 実装済み／R5 の対応を付記。
- §3-1: `jasmin_order_id` → `order_id`、`performed_by` をポリモーフィック（Customer/SalesRepresentative/User）、`method` は enum ではなく string+inclusion。**置き場案**（顧客Webチェック=form or mypage、営業記録=form、管理者閲覧/項目セット版管理=admin + Pundit）。activitylog → `Auditable`/`AuditLog`（`user_id NOT NULL` のため顧客本人の実施は AuditLog に載らない可能性→証跡は `disclosure_checks` で完結）。同意系カラムは R2 実装済みと注記。
- §3-2: `file_path` → Active Storage `has_one_attached :file`、`(order_id, document_type, version)` unique、`notification_ref` の Rails 実装案。**PDF 生成基盤の候補比較表（grover/ferrum vs prawn。03§2）**と共用 Service（`Documents::PdfRenderer` + `OrderDocumentGenerateJob`）案。R4 の実態（`Notification has_many_attached`、`NotificationDeliveryJob`、`TEMPLATE_TYPES` 3値、`RecipientResolver`）で読み替え、Q-7 の Rails 版推奨 = (b) 専用 `OrderDocumentMailer` + `deliver_later`（R4 Inquiry 通知と同型）。**`applications.form_data` は完了時にクリアされる現行実装**のため、確認書スナップショットは生成時に Customer/Store/Order から組み立てて `source_snapshot` に固定する必要あり（Q-6 の前提として明記）。
- §4: P3-12 の前提（受注入力画面）は R3 で充足済み、P3-13 の送付トリガ（PaymentTransaction authorized or 口振/おまとめ時 Application 完了）、E2 宛先ルール未確定（04 R4 ギャップ）を注記。
- §5: **Q-1〜9 は 04 Q-35 に一括対応**と付記。Q-1〜6/8/9 = 業務・法務判断、Q-7 = 開発判断（推奨あり）。論点自体は無変更。§6 変更履歴に追加。

### 現行実装との差分・未実装事項
- 未実装（R5）: `disclosure_item_sets`/`disclosure_items`/`disclosure_checks`/`disclosure_check_items`、`order_documents`/`order_document_deliveries`、PDF 生成、確認書メール、契約書生成/署名。
- 実装が設計と異なる: `form_data` クリア（スナップショット源にできない）。`notification_attachments` テーブルは存在せず Active Storage。

---

## 4. 04-rails-implementation-plan.md へ反映すべき事項

### 4-1. R5 の実装タスク分解案（順序付き・04 R5節へ）

| 順 | タスク | 出典 | 優先度 |
|---|---|---|---|
| R5-0 | 着手前チェックリスト（Q-25〜27・Q-35〜39・Q-D・E6）確定。加えて **§4-10 の section 配置（ret_url = form）と カード変更導線の section** を CTO 判断で確定 | payment §8/§4-10 | ブロッカー |
| R5-1 | 契約ワークフロー状態機械（P3-4）の設計確定 — `orders.status`/`contract_status` の遷移表、決済未完了 Order の扱い、重説完了を遷移条件にするか（Q-4） | p3-12-13 §4、payment §2-2/§4-6 | 高（他タスクの前提） |
| R5-2 | migration: `payment_transactions` / `payment_transaction_logs`（§5）、`customers.netmove_member_id` 部分ユニークインデックス、`Auditable TRACKED_FIELDS` へ `PaymentTransaction`・`Customer.netmove_member_id` 追加 | payment §5、netmove §6-2/6-5 | 高 |
| R5-3 | `PaymentTransaction` 状態機械（遷移表・mark/confirm・with_lock・lock_version）+ model spec | payment §4-4 | 高 |
| R5-4 | `app/services/payment/`: Config（サイト別 credentials）/ CheckCode（HMAC）/ JutyuCodeGenerator / MemberIdAllocator / CardholderInfoBuilder / ParamMasker + unit spec | payment §4-9/§4-10、netmove §6 | 高 |
| R5-5 | Solid Queue 決済専用キュー（`config/queue.yml` payments ワーカー、`retry_on` 禁止、`limits_concurrency`）+ job spec | payment §4-2 | 高 |
| R5-6 | 決済開始 `Form::PaymentsController` + `Payment::CheckoutSession`（送信前レコード・自動送信フォーム）+ D-P12① 3択分岐（おまとめ時スキップ）+ 3DS 項目送信（P3-2-l） | payment §4-10、§4-7、D-P12 | 高 |
| R5-7 | ret_url/cancel_url 受け口 `Form::PaymentReturnsController` + `Payment::ReturnHandler`（skip_forgery_protection・セッション不参照・check_cd 検証・member_id 空→unknown・cancel では遷移しない）+ rack-attack + **request spec（Cookie無し/改ざん/二重POST）** | payment §4-9/§4-10、R-12 | 高 |
| R5-8 | `Payment::OrderStatusSyncService`（決済→業務ステータス連動。R5-1 の対応表に従う） | payment §4-6 | 中 |
| R5-9 | 管理画面 `Admin::PaymentTransactionsController`（一覧/詳細/手動再開/突合確定）+ `PaymentTransactionPolicy` + `Admin::PaymentReconciliationsController`（CSV取込）+ `Payment::ReconciliationJob`（`ReconciliationSources::ManualCsv`） | payment §4-3/§4-10、P3-2-f/g | 中 |
| R5-10 | 請求用受注データCSV: `CsvExportJob::EXPORT_TARGETS` に `"BillingOrder"` を追加（列は TBSS ヒアリング後）。R6 汎用化時に移管 | payment §4-8/論点14 | 中（カットオーバー締切あり） |
| R5-11 | PDF 生成基盤選定（grover/ferrum vs prawn）+ `Documents::PdfRenderer` + `OrderDocument`/`OrderDocumentDelivery` migration + `OrderDocumentGenerateJob` | p3-12-13 §3-2 | 中 |
| R5-12 | 申込確認メール（P3-13）: `OrderDocumentMailer` + `NotificationTemplate` 値追加 + `RecipientResolver` で E2 宛先 + source_snapshot 生成 | p3-12-13 §3-2 Q-7 | 中 |
| R5-13 | 重説チェック（P3-12）: `Disclosure*` 4テーブル + 実施UI（section は Q-2 次第）+ 管理画面版管理 + Policy | p3-12-13 §3-1 | 中（R5-1 の後） |
| R5-14 | 契約書PDF・版数管理・契約確認メール・手書き署名（P3-8/9。R5-11 の器を共用） | 04 R5 既存項目 | 中 |
| R5-15 | 実結線確認（P3-2-i）は Q-39 確定後（商用カード・1円与信＋与信取消） | payment §6/R-6 | — |
| R5-16 | カード変更導線（member-modify）は **スコープ境界として明記のみ**（S-7 回答後に実装） | netmove §3/§6-4 | 低 |

### 4-2. 04 への追記・変更提案
- R5節「決済専用キュー」項に **`config/queue.yml` に payments ワーカー追加・`retry_on` 禁止・`limits_concurrency`** の具体を追記（出典 payment §4-2）。
- R5節に **「ret_url 受け口は form section（`Form::PaymentReturnsController`）に置き、`skip_forgery_protection` + 認証スキップは当該コントローラに閉じる」** をCTO決定候補として追記（出典 payment §4-10。03§8-2 と同様の自律決定枠）。
- R5節に **`payment_transaction_logs` を AuditLog と別に持つ理由（`audit_logs.user_id NOT NULL`）** を追記（出典 payment §4-5）。
- R5節「ネットムーブ会員ID引き継ぎ」に **`customers.netmove_member_id` 部分ユニークインデックス**と **Auditable TRACKED_FIELDS 追加**を追記（出典 netmove §6-2/6-5）。
- R5節「請求用受注データCSV出力の実装先」に **推奨＝R5 で `EXPORT_TARGETS` 1エントリ先行、R6 で汎用化へ移管** を追記（出典 payment §4-8）。
- R5節に **PDF ライブラリ選定は R8 の Docker/デプロイ構成（Chromium 同梱可否）と連動**を追記（出典 p3-12-13 §3-2）。
- R5節「実装順の知見」に **`applications.form_data` は完了時にクリアされるため確認書スナップショットは Customer/Store/Order から生成時に固定**を追記（出典 p3-12-13 §3-2）。
- R7節に **`lib/tasks/etl/netmove_member_ids.rake`（顧客管理エクスポート→`customers.netmove_member_id`）** をタスク名として追記（出典 netmove §3/§6-1）。
- R5着手前チェックリスト Q-36 に「payment-integration.md の結論（`customer_id` + `order_id` 併記）で確定として閉じてよいか」を付記。

## 5. 決定者/業務側の確認が必要な未決論点
- **Q-25〜27**（返金/キャンセル・信販・決済障害縮退）— 未解決のまま。Q-25 は状態機械の refunded/canceled 遷移と管理画面「与信取消」操作の要否に直結。
- **Q-35 = p3-12-13 Q-1〜9** — Q-1〜6/8/9 は業務・法務判断（重説項目の定義者・実施者/方式・紐づけ単位・遷移条件・確認書テンプレ/スナップショット/再送・Cc・保存期間）。Q-7 は開発判断で可（推奨 (b)）。
- **Q-36** — payment-integration.md §8 論点9 の結論（`customer_id` 主・`order_id` 登録契機）で閉じてよいか。
- **Q-37 / Q-38 / Q-39** — ネットムーブ依頼（D-1/D-5、C-1〜C-4、E-1〜E-4）の回答待ち。依頼書ドラフト `drafts/netmove-request-draft.md` は旧Laravel側 `requirements/drafts/` に残存し brige-crm 未コピー（要否判断）。
- **カード変更（member-modify）導線の section**（mypage で顧客本人 / admin からメールリンク案内）— S-7新（現行手順）の回答待ち。
- **会員ID採番形式**（「6＋7桁連番」仮説）— リクリック質問■1 / D-5 / S-3 の回答待ち。確定まで `MemberIdAllocator` の形式は固定しない。
- **請求用受注データCSVの列定義**（論点14）— TBSS ヒアリング（S-1）。カットオーバー後最初の25日前後が締切。
- （CTO判断で可）ret_url 受け口を form section に置く案の採否、Webhook 提供時の `webhooks/` 名前空間新設可否。

---

<!-- ===== summary-D-r4-status ===== -->

## サマリ D: R4（問い合わせ・通知）／ステータス領域 — 設計ドキュメント Rails版改訂（2026-08-19）

担当ファイル（3件・全て上書き改訂済み、章番号維持、改訂ヘッダ追加。git操作・他ファイル編集なし）:
- `requirements/design/board-implementation-options.md`
- `requirements/design/notification-matrix.md`
- `requirements/design/status-naming-analysis.md`

突合した実装: `app/models/inquiry*.rb` `inquiry_status.rb` `inquiry_recipient_route.rb` `notification*.rb` `recipient_group*.rb` `system_notification.rb` `customer_status.rb` `order_status.rb` `concerns/system_managed_status.rb`、`app/services/recipient_resolver.rb` `inquiry_notifier.rb` `status_seeder.rb`、`app/jobs/*` `app/mailers/*`、`app/controllers/admin/{inquiries,inquiry_messages,inquiry_recipient_routes,inquiry_statuses,notifications,notification_templates,recipient_groups,customer_statuses,order_statuses}_controller.rb`、`app/controllers/form/applications_controller.rb`、`app/policies/inquiry_policy.rb`、`app/views/admin/{customer_statuses,order_statuses,customers,orders,inquiries,notifications}/`、`app/views/mypage/dashboard/`、`config/routes.rb` `config/recurring.yml` `db/schema.rb` `db/seeds.rb`、`spec/requests/admin/inquiries_spec.rb` `spec/services/recipient_resolver_spec.rb` `spec/jobs/inquiry_message_mail_job_spec.rb` `spec/models/system_notification_spec.rb`。

---

## 1. board-implementation-options.md（決定D-11 の根拠文書）

### 主な改訂内容
- 改訂ヘッダ追加（R4=Inquiry拡張本体 実装済み／R7=アーカイブ投入 未着手）。ステータスを「判断材料」→「決定済み（D-11）＋R4実装突合済み」に更新。
- **§0「R4 実装突合サマリ」を新設**（章番号は追加のみ）: スレッド／種別／種別別ステータスマスタ（`InquiryStatus`+`StatusSeeder::INQUIRY_STATUSES` 8/7/6/4値）／ステータス駆動ルーティング（`InquiryRecipientRoute`+`RecipientResolver.route_for`、返信時 `params[:status]` 更新→宛先解決）／案件経由の自動宛先／アフター固有6列／メール（`InquiryMessageMailJob`→`InquiryMailer`）／アプリ内通知（`InquiryNotifier`→`SystemNotification`+Solid Cable+30日prune）／添付（Active Storage 5×50MB）／権限（Pundit `InquiryPolicy`）／採番（`SequenceCounter`）／画面／アーカイブ／テストを「実装済み／差分／未実装」で表化。
- §2-1 を「Q-C判断時点（Laravel）」「R4（Rails）」の2列に、§2-2 ギャップ表に「R4での解消状況」列を追加。
- §3 に採用／不採用を明記、§4/§6/§7 を R7 前提へ更新（Artisan→rake/`rails runner`、`legacy_bbs_archives` 未定義、Q-44）。
- §5 業務確認チェックリストに「実装先行・未回収」注記と、実装で判明した確認事項2件を追加。§8 変更履歴追記。

### 現行実装との差分・未実装事項
- 実装済み（R4）: 種別別ステータスマスタ・enum撤廃、種別×ステータス→宛先ルーティング、返信時ステータス更新、メール/アプリ内通知、添付、Pundit スコープ、採番テーブル化。
- **差分（要確認）**: `RecipientResolver#recipients_for_inquiry` が**全投稿で案件の代理店（email_1〜5）・営業担当者・顧客のメール保持者を必ず宛先に含める**（05§5-1 は販売店宛をステータス限定・顧客宛なし）。`is_visible_to_agent=false` でも代理店へメールが飛ぶ。投稿者による宛先の手動選択 UI は無し（自動固定）。
- 差分（小）: 添付 MIME 制限未移植、heavy-processing キュー分離なし（Solid Queue default）。
- 未実装（R4追補 or 業務確認後）: `InquiryRecipientRoute`／`RecipientGroup` の初期投入（05§5-1 マトリクス相当のシード無し）、アフター固有列のフォーム UI・選択肢マスタ化、**次回対応者によるルーティング（05§5-2）**、外部委託先アドレスの宛先化（`RecipientGroupMember` は User/ProductionCompany のみ・UI は User のみ）、`inquiry_statuses`/`inquiry_recipient_routes` の request spec。
- 未実装（R6）: 通知一覧・既読 UI、メッセージ単位既読、通知要否とステータスの分離（C6）。
- 未実装（R7）: `legacy_bbs_archives`（42万件参照アーカイブ）。案件（Order）ステータス遷移との連動は R5/R6 の設計課題。

### 04 へ反映すべきタスク
| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R4追補 | 高 | 05§5-1/5-2 のマトリクスに相当する `RecipientGroup`／`InquiryRecipientRoute` の初期投入（シード or 運用手順書）。外部委託先アドレスの User/ProductionCompany 化方針を含む | board §0・§5 |
| R4追補 | 高 | `recipients_for_inquiry` の合成規則の業務確認→修正（顧客・営業担当者を全投稿に含めるか、`is_visible_to_agent=false` の除外） | board §0 差分・§5 |
| R4追補 | 中 | アフター固有列（after_urgency/after_type/after_area/reception_channel/first/next_responder_name）のフォーム配置・選択肢固定値化、次回対応者ルーティングの要否 | board §0・§2-2 |
| R4追補 | 低 | `inquiry_statuses`/`inquiry_recipient_routes` CRUD の request spec | board §0 |
| R7 | — | `legacy_bbs_archives` 設計（UUID PK・target_id→orders.id 解決・pg_bigm 全文検索）。Q-44 と同時 | board §6 |

### 決定者/業務側の未決論点
- 後確/制作/検収を「問い合わせ」画面系に載せた呼称・動線（現行フォームのラベルは「掲示板種別」）。
- アフター3軸・受電窓口・初回/次回対応者の要否（実装は全部保持・自由文字列）。
- 通知目的ステータスの通知機能への分離可否（C6）。
- 過去42万件アーカイブの運用要件（Q-44）。
- **全投稿を顧客・営業担当者へ自動送信する現行実装の是非**（新規）。
- 外部委託先アドレスの宛先化方法（G-7）（新規）。

---

## 2. notification-matrix.md（Q-21）

### 主な改訂内容
- タイトルを「実装突合済み版」に、ステータスを「叩き台→実装突合済み版（Q-21 業務確認は未了）」へ格上げ。改訂ヘッダ追加（R4／R3／R5／R6 対応）。`ftlog-port.md`・`development-plan-review-20260726.md` 参照は削除済み注記へ差し替え。
- §0 受信者列に「R4 実装での対応」列を追加（管理者=専用経路なし／バックヤード=実務運用者ロール or RecipientGroup／代理店=email_1〜5／営業=個人宛あり／顧客=メール+SystemNotification）。
- **§1 E1〜E12 に「実装済みルール」列を追加**、E13（一斉通知 `Notification`）を新規追加。
- §2 横断ルール C1〜C7 に実装状況列を追加。§3 論点に実装状態・担当フェーズを追記し、論点13〜15 を新規追加、論点11（Q-C連動）を解消。

### E1〜E13 の実装確定状況（04 反映用）
| E | イベント | 状態 | 担当フェーズ | 実装済みルール／未決内容 |
|---|---|---|---|---|
| E1 | 申込受付 | 実装済み | R3 | `StaffNotificationMailer.new_application` → `実務運用者` ロール全 active User へメール。管理者/代理店/営業/顧客には送らない。`SystemNotification` type `application_completed` は未使用 |
| E2 | 申込確認メール | 実装済み（添付なし） | R3（確認書PDF添付は R5） | `Form::ApplicationMailer.confirmation` → 顧客メールのみ・Cc なし。Cc 要否は要確認 |
| E3 | 不備差戻し | **未実装・要確認** | R5（契約ワークフロー状態機械） | ステータス変更はイベント通知を発火しない |
| E4 | 確認コール結果（後確） | 実装済み（差分あり） | R4 | 案件の代理店/営業/顧客（全ステータス）＋`InquiryRecipientRoute(後確×status)` のグループ。メール＋SystemNotification。**顧客○・営業○・代理店全ステータス○は 05 と差分** |
| E5 | 契約確定 | **未実装・要確認** | R5 | 契約書PDF・メール送付と同時 |
| E6 | 決済失敗 | **未実装・要確認** | R5（着手前チェックリスト） | 決済系テーブル自体未実装。D-P5/Q-25 と併せて確定 |
| E7 | 遅延案件 | **未実装・要確認** | R6 | recurring ジョブ＋SystemNotification＋メールで設計 |
| E8 | 自動キャンセル | **未実装・要確認** | R6（着手前チェックリスト） | 代理店通知は E4 経路流用可。**顧客通知要否**が未決 |
| E9 | 掲示板ステータス通知（制作/検収） | 実装済み（差分あり） | R4 | E4 と同一機構。ルート初期データ未投入 |
| E10 | 問い合わせ（アフター） | 実装済み（一部未実装） | R4 | E4 と同一機構。**次回対応者ルーティング未実装** |
| E11 | メンション | 未実装 | R6 | Pundit `InquiryPolicy` を可視性再判定に流用 |
| E12 | 一斉通達 @ALL | 未実装 | R6（E11 と同時） | 顧客を候補集合に含むか未決 |
| E13 | 一斉通知（お知らせ配信） | 実装済み（新規行） | R4 | `Notification`（agency/customer × filter_params）→ `NotificationDeliveryJob`→メールのみ。フィルタ入力 UI 未配置。`notification_sent` SystemNotification 未使用 |

横断ルール: C3 実装済み（`system_notifications` 名称差）／C5 ステータス側実装済み／**C4 件名形式は差分**（`【問い合わせ】タイトル（INQ-xxxxxx）` 等、統一形式未適用）／C1（自己操作抑制）・C2（通知設定 ON/OFF）・C6（通知とステータス分離）・C7（FAQ テンプレ318件）未実装。

### 04 へ反映すべきタスク
| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R4追補 | 高 | E4/E9/E10 の差分（顧客・営業への全投稿自動送信、`is_visible_to_agent=false` 時の代理店送信）の業務確認と `RecipientResolver` 修正 | matrix §1・§3-13 |
| R4追補 | 中 | 一斉通知フォームにフィルタ UI（agency_group_id/status/agency_id）追加（ラベル「申込ステータス」） | matrix E13 |
| R4追補 | 中 | 件名形式（C4）統一要否の確認→`InquiryMailer`/`NotificationMailer` 修正 | matrix §2 C4・§3-14 |
| R5着手前 | 高 | E3/E5/E6 の宛先・Cc 確定（E6 は D-P5/Q-25 と同時） | matrix §1・§3-6/7 |
| R6着手前 | 高 | E7/E8 の宛先確定（E8 顧客通知要否）、E11/E12（メンション/@ALL）の候補集合に顧客を含むか | matrix §3-8/9/10 |
| R6（前倒し検討） | 中 | 通知一覧・既読 UI（admin/mypage）、C1/C2 通知設定、C6 通知しないオプション | matrix §2・§3-15 |
| R4後続/R6/R7 | — | C7 FAQ テンプレ（既に 04 に 決定者 確認事項として記載あり） | matrix §2 C7 |

### 決定者/業務側の未決論点
- 論点1〜10（バックヤード定義・管理者通知・営業個人宛・E1〜E8・E12）は依然未確認。実装済みイベント（E1/E2/E4/E9/E10/E13）は実装が暫定回答。
- 新規: 論点13（全投稿の顧客・営業自動送信）、論点14（件名統一）、論点15（通知一覧 UI 無しで運用開始してよいか）。

---

## 3. status-naming-analysis.md（Q-B）

### 主な改訂内容
- 改訂ヘッダ追加（R2 実装済み／R4 InquiryStatus／R5 状態機械／R6 遷移バリデーション／R7 マッピング）。ステータスを「決定済み（D-8 案A承認）＋実装適用状況突合済み」に更新。
- **§0-1「Rails 実装への適用状況」を新設**: order_statuses 側マスタ画面は適用済み、**customer_statuses 側は全面未適用**（実ファイル・行を列挙）、案件画面側も「案件ステータス」の明示漏れ。
- §1 の Laravel 記述（`JasminCustomer`/`JasminOrder`・`database/migrations/*.php`・`SampleDataSeeder`・Vue）を Rails 版（`Customer`/`Order`・`CustomerStatus`/`OrderStatus`・`SystemManagedStatus` concern・`StatusSeeder`・ERB・Pundit・Auditable）へ書き換え。§1-4（InquiryStatus）追加。
- §3-1 に D-8 採用済みを明記、Phase 2 の `ApplicationStatus` 命名が既存 `Application` モデルと衝突する注意を追加。
- **§4-1/4-1b を実ファイル・行番号で再確認した修正ファイル一覧に更新**（下記）。§5 に論点5・6 追加。§6 変更履歴追記。

### 現行実装との差分・未実装事項
- 案A の適用: `order_statuses` マスタ画面（index/new/edit h1）・モデル/コントローラコメント・factory は「案件ステータス」で適用済み。`customer_statuses` 側は未適用（旧称「顧客ステータス」のまま）。案件/顧客の各画面は「ステータス」のみで語を明示していない。
- **customer_statuses の code 識別子が Laravel シードと異なる**（Rails: needs_correction/confirm_call_pending/confirm_call_done/needs_reconfirmation/contracted、Laravel: reviewing/awaiting_call/call_done/re_confirm/confirmed。ラベルは同一）。is_system は applied/withdrawn の2値のみ。
- **order_statuses のシードは5値のみ**（0:受注/10:作業進行中/21:解約/22:強制解約/100:CLOSE）。35値の投入は未了（R5 統廃合時）。
- ステータス遷移バリデーションは未実装（04 R6 に既記載）。`orders.contract_status` は長さ検証のみで値リスト定数なし。
- 一斉通知の申込ステータス絞り込みはモデルにあるが UI 未配置。サイドバー（Laravel `AppSidebar.vue`）相当は Rails 版に無い。

### customer_statuses 側の呼称統一に必要な修正ファイル一覧（04 R2 追加タスク反映用）
必須（「顧客ステータス」→「申込ステータス」）:
- `app/views/admin/customer_statuses/index.html.erb` 2行目 h1
- `app/views/admin/customer_statuses/new.html.erb` 2行目 h1
- `app/views/admin/customer_statuses/edit.html.erb` 2行目 h1
- `app/views/admin/customers/_form.html.erb` 23行目 `f.label :status, "ステータス"` → 「申込ステータス」
- `app/views/admin/customers/show.html.erb` 6行目 dt「ステータス」→「申込ステータス」
- `app/views/admin/customers/index.html.erb` 23行目 th「ステータス」→「申込ステータス」
- （将来）`app/views/admin/notifications/_form.html.erb` にフィルタ UI を追加する際のラベル
任意（コメント）:
- `app/models/customer_status.rb` 1行目、`app/controllers/admin/customer_statuses_controller.rb` 1行目、`db/migrate/20260815140002_create_customer_statuses.rb` 3行目、`db/seeds.rb` 4行目、`spec/factories/customer_statuses.rb` 29行目
案件側の明示（「ステータス」→「案件ステータス」、任意だが同時対応推奨）:
- `app/views/admin/orders/_form.html.erb` 44行目、`app/views/admin/orders/show.html.erb` 9行目、`app/views/admin/orders/index.html.erb` 23行目、`app/views/mypage/dashboard/index.html.erb` 7行目（「状態」。顧客向け文言は業務確認）
設計文書（別担当）: `requirements/design/Column.md` 698行目「顧客ステータス」→「案件ステータス（旧称: 顧客ステータス）」、460行目「ワークフローステータス」→「申込ステータス」。

### 04 へ反映すべきタスク
| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R2追加（R5前） | 高 | 案A（D-8）を 04 本文に正式決定として記録し、上記ファイル一覧の表示文字列を修正（ビュー6件＋コメント5件＋案件側4件） | status §0-1・§4-1/4-1b |
| R5 | 高 | `order_statuses` 35値の投入・統廃合（現シード5値）と code 安定キー化の判断（`OrderStatus::CODE_ORDERED` 連動） | status §1-2・§5-2/3 |
| R5/R6 | 中 | 申込8値と案件35値の意味重複（案C送り）: 申込ステータスを案件側から導出するか独立管理か。`Customer.active`/Devise 認証可否が withdrawn に依存 | status §5-1 |
| R7 | 中 | 旧「59 顧客ステータス」→ `orders.status` 対訳、Laravel code 識別子（reviewing 等）→ Rails code（needs_correction 等）の読み替え | status §5-5 |
| R8 | 低 | 用語集（案件/申込/契約/問い合わせステータス）新設・現場向け読み替え表（Q-20） | status §4-2・§5-4 |

### 決定者/業務側の未決論点
- 04 次のアクション5「Q-B（customer_statuses を申込ステータスへ統一するか）」は D-8 で既に決定済み（development-plan.md §8）。**04 側に決定記録が無いだけ**なので、確認は「D-8 のとおり実装適用を進めてよいか」の再確認で足りる。
- Phase 2（テーブルリネーム）は「やらない」で確定するか（`ApplicationStatus` 命名衝突あり）。
- マイページの案件列名（「状態」のままか「案件ステータス」か）。

---

## 横断: 03/04 との整合メモ
- 04 R4「掲示板4種→問い合わせ統合（決定D-11）」の4項目（種別別ステータスマスタ化・enum撤廃・種別×ステータス→宛先ルーティング・アフター固有列追加）は**すべて実装済み**（アフター固有列は列のみ・UI 未）。04 R4 に「実装済み」を明記可。
- 04 R4 未実装ギャップ「通知マトリクスの未決事項が答え合わせされないまま実装が先行」は、本改訂で notification-matrix.md に実装済みルールを記録したことで「記録無し」状態は解消。業務確認自体は R5/R6 着手前チェックリストへ。
- 04 リスク6（呼称の中途半端な適用）は status-naming-analysis.md §0-1/§4-1 に修正対象を確定済み。

---

<!-- ===== summary-E-form-pii ===== -->

## サマリ E: R3 申込フォーム／PII 領域（form-template-mapping.md・pii-handling-rules.md）— 2026-08-19

## 1. `requirements/design/form-template-mapping.md`（322行 → 445行）

### 主な改訂内容
- 改訂ヘッダ追加（フェーズ対応: R3 実装済み／WorkDetail 組み込み＝旧 Phase 4 → R6）。章番号 1〜8 維持、§9「実装突合表（2026-08-19）」を新設。
- §1: 「単一の信頼できるソース」を Laravel の `FormTemplateDefinition::FIELDS`（コード定数）から **DB `form_templates/form_steps/form_fields`＋フォームビルダー（`Admin::FormTemplatesController`）** に書き換え。§1-2 を Laravel メタデータ→`form_fields` カラム対応表（`field_type` 読替: email/tel→text、number→integer、radio→select/boolean、`option_group_key` は未実装＝`input_options.choices` インライン、`editable_by_tier`/`lock_after_status`/ホワイトリスト検証 `FormField.allowed_target_columns_for`）に置換。
- §2: target_table を `customer/store/order` に読み替え、§2-3「新規カラム追加が必要」→ **R2 スキーマで全実装済み**（`customer_name_kana` の保存先のみ `contractor_name_kana` に列名差異）に更新。
- §3: OptionGroup は FormField から参照されない（インライン choices）こと、`prefecture`/`payment_method` を含め **OptionGroup シーダーが未作成**（開発DB 0件）を注記。
- §4: 契約後スタッフ入力カラムが**ホワイトリストから除外されていない**（運用ルール止まり）こと、加えて `customer` 側で Devise/OTP 認証列・`netmove_member_id` が許可されている点を「要確認・要対応」として注記。
- §5: `order_work_detail` の target_table・`apply_order_work_detail!` は R3 で機構実装済み、encrypts 8列は自動除外、個別フィールド投入は R6。
- §6: 6-1（動的マッピング）・6-4（integer キャスト）・6-5（Vue バインディング）を「実装済み／解消」に。6-2（契約者住所）は customers 側で解消。**6-3 は論点変更**: yes_no 保存先が string(5) のため `field_type: boolean` だと `"t"/"f"` が入る（`rails runner` で確認）→ select ＋ 文字列表記を要決定。**6-6 新規**: email/tel の形式検証が無い。
- §7: 決定事項 5 完了、6/7/8 未決を明示、**9（BRIDGE_PLUS 初期テンプレート投入手段）・10（§4 カラムのホワイトリスト除外要否）を新規追加**。§8: Phase 3.5 の各 Step を R3 実装状況（済/未/不要）に対応付け。

### 現行実装との差分・未実装事項
- フレームワーク（target_table/target_column/editable_by_tier/lock_after_status/動的マッピング/ホワイトリスト/request spec）: **R3 実装済み**。
- **未反映フィールド: 67 / 67 件（全件）** — §2 の field_key 実数は 67（2-1: 12 / 2-2: 43 / 2-3: 12。04・review-05 の「155項目」は §4・§5 等を合算した概数と判断）。BRIDGE_PLUS 用 FormTemplate/FormStep/FormField は **seed・factory・開発DB のいずれにも存在せず**、実商材のテンプレート定義データが未投入。
  - 内訳: A「保存先カラム実在・ホワイトリスト許可・定義未投入」66件（customer 10 / store 12 / order 44）／B「列名差異（`name_kana`→`contractor_name_kana`）」1件／C「列無し・要マイグレーション」0件。
  - 型読替が要るもの（Aの内数）: radio 15（yes_no 系14は string(5) 列→boolean 不可）、tel 5・email 1（形式検証なし）、number 5→integer、date 1（`confirm_call_preferred_date` は string 列）、select 8（インライン choices）。
- OptionGroup シーダー（prefecture / payment_method / yes_no / applicant_type 等）未作成。

### 04 へ反映すべき新規タスク／変更
| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R3 残（R5 着手前） | 高 | BRIDGE_PLUS 初期テンプレート 67 フィールドの投入手段決定（(a) ビルダー手入力 / (b) seed・rake / (c) インポート機能）と投入。OptionGroup シーダー併設 | form-template-mapping.md §7-9・§9-1・§9-2#1 |
| R3 残 | **高（セキュリティ）** | `FormField.allowed_target_columns_for("customer")` が Devise/OTP 認証列（`encrypted_password` `otp_code_digest` `otp_code_expires_at` `otp_attempts` `unlock_token` `locked_at` `failed_attempts`）と `netmove_member_id` を許可 → 除外リスト追加＋spec | §4 注記・§9-2#2 |
| R3 残 | 中 | §4 契約後スタッフ入力カラムのホワイトリスト除外要否（業務判断） | §7-10・§9-2#3 |
| R3 残 | 中 | `validation_rules` に format 検証（email/tel/postal_code）追加。`customers.email` はマイページのログインID | §6-6・§9-2#5 |
| R3/R7 | 中 | yes_no 系 string(5) 列の保存値表記の決定（R7 移行元表記と整合） | §6-3・§7-6 |
| R6 | 低 | `input_options.option_group_key`→OptionGroup 参照解決（任意）／WorkDetail 個別フィールドのフォーム組み込み範囲 | §3・§5・§7-8 |
| 04 R3要確認の文言 | — | 「155項目」→「67 field_key（§2）」に訂正し、突合結果（全件未投入・列は全て実在）を記録 | §9 |

### 決定者/業務側の確認が必要な未決論点
- 初期テンプレートの投入手段（§7-9）と、投入前提の選択肢確定（§7-7: consent_status / business_proof / elderly_consent / business_auth_doc / applicant_type の値）。
- yes_no 保存値の表記（§7-6）。
- §4 業務カラムをフォームから機構的に締め出すか（§7-10）。

## 2. `requirements/design/pii-handling-rules.md`（188行 → 255行）

### 主な改訂内容
- 改訂ヘッダ追加（フェーズ対応: R2 実装先行／R7 ETL／R8 release C-3・C-5・G-8）。章番号 1〜8 維持。
- §1 表に「Rails版の保存先と保護状態」列を追加（A: 平文＋アクセス制御・決定無し／B: `encrypts` 9列 実装済み／C: 平文・未決）。**§1-1 新設**: 横断的保護機構の実装済み一覧（`encrypts`・`filter_parameter_logging`（`:pass` 追加済み）・`Auditable::TRACKED_FIELDS`→`AuditLog`・`Application#form_data` クリア・ホワイトリスト・Pundit/RBAC/IP許可リスト・CsvExport）。
- §2: パスを Rails 版へ（`storage/*` gitignore 済み、`requirements/input/` は brige-crm に無い→R7 で追加提案、`spec/fixtures`・`db/seeds*` への実データ禁止、CI は `.github/workflows/ci.yml`）。CSVエクスポート生成物の保持期限・自動削除（Solid Queue recurring）を提案。親 `.gitignore` の `private/` 行番号を再検証（38行目）。
- §3-2: `spec/`・FactoryBot・`*_seeder.rb`、`Rails.logger` に実値を出さない慣行を追記。§4: rake/`rails runner`・`storage/private/etl/`。**§4-4 新設**: encrypts 列への load は必ずモデル経由（bulk insert は平文になる）。
- **§5 を「Q-D の現状と決定待ち事項」に改訂**: 5-1 現状表（Q-D原義=未決／分類B=実装済み／分類A=暗号化しない方針で実装先行・決定記録無し／分類C=未決）、5-2 決定候補案 Q-D-1（分類B を運ぶ/運ばない）・Q-D-2（A-1 現状追認 / A-2 選択的暗号化 / A-3 全面暗号化: コスト・検索性への影響つき）・Q-D-3（分類C: C-1 deterministic encrypts / C-2 平文）。推奨: A-1・C-1。
- §6: ai-git.sh ゲート・Rails credentials 流出時の鍵ローテーションを追記。§7: 完了条件 3・4 を Rails 版の状態に更新、Q-D の決定期限（Q-D-2=R8 前、Q-D-3=R5 前、Q-D-1=R7 前）を明記。§8 変更履歴追加。

### 現行実装との差分・未実装事項
- 実装済み（R2/R3）: 分類B 9列の `encrypts`、ログフィルタ、監査ログ除外、form_data クリア、ホワイトリスト。
- 未実装: CSVエクスポート生成物の保持期限・自動削除（R6 提案）、`requirements/input/` 受け口（R7）、`*.real.csv` gitignore パターン・PII 検出 CI ガード（提案）、分類C 暗号化（R5 前に決定）、鍵ローテーション手順（R8）。

### 04 へ反映すべき新規タスク／変更
| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R2 残タスク／リスク5 | 高 | 「PII方針（Q-D）」を **Q-D-1〜3 に分割**して決定を記録（下記選択肢）。リスク5「R2着手前に確定」→「Q-D-2 は R8 前・Q-D-3 は R5 前・Q-D-1 は R7 前」に改訂 | pii §5-1・§5-2・§7 |
| R5 着手前チェックリスト | 高 | Q-D-3（`netmove_member_id` 等 分類C の暗号化方針。推奨 C-1 deterministic encrypts）を追加 | pii §5-2 |
| R6 | 中 | CsvExport 生成物の保持期限＋自動削除ジョブ（Solid Queue recurring） | pii §2-2 |
| R7 | 中 | `requirements/input/` gitignore 受け口の作成、ETL の encrypts 列はモデル経由 load、分類B 隔離中間ファイルの削除タイミング | pii §2-2・§4-4 |
| R8（release C-3/C-5/G-8） | 中 | DB/バックアップ at-rest 暗号化の要件化（A-1 採用の条件）、credentials 流出時の鍵ローテーション手順、Q-A 完了条件 4（development-plan.md Q-A 行・release-readiness C-5/G-8 の更新） | pii §5-2・§6・§7 |

### 決定者 へ提示すべき Q-D の選択肢（04 反映用）
- **Q-D-1 分類B（SNS認証情報）を新システムへ運ぶか**: (i) 運ぶ（encrypts 済み列へモデル経由 load）／(ii) 運ばない（移行対象外・以後は新規入力または別管理）。R7 前に決定。
- **Q-D-2 分類A（Customer/Store 本体 PII）の暗号化**: A-1 現状追認（平文＋アクセス制御＋at-rest 暗号化。コスト低・検索性影響なし。**推奨**）／A-2 選択的暗号化（検索キーでない連絡先列のみ非決定的 encrypts。コスト中）／A-3 全面暗号化（email は deterministic、name はブラインドインデックス列追加。コスト高・LIKE/pg_bigm/ソート不可＝03 決定A(pg_bigm)と矛盾）。R8 前に決定。
- **Q-D-3 分類C（netmove_member_id 等）**: C-1 deterministic encrypts（等価検索可・**推奨**・R5 前なら手戻り無し）／C-2 平文＋アクセス制御。R5 前に決定。
- Q-A 側: ルール本体の承認、担当者割当（§7-2）、発注元への匿名化提起の要否（§7-5、外部アクション）。

## 3. 補足
- 編集ファイルは担当2ファイルのみ。git 操作なし。実装コード・04・他ドキュメントは未変更。
- 突合に用いたコマンド: `docker compose exec web bin/rails runner`（FormField/OptionGroup 件数＝0、`FormField.allowed_target_columns_for` の出力、`Order.new(plus_applied: true).plus_applied #=> "t"`）。credentials は読んでいない。

---

<!-- ===== summary-F-r6-ops ===== -->

## サマリ F: R6（運用強化）領域 3ファイルの Rails版改訂（2026-08-19）

対象: `requirements/design/customer-merge-design.md`（253→303行）/ `export-profile-design.md`（169→196行）/ `business-flow-analysis.md`（315→350行）。章番号は維持。git 操作・他ファイル編集なし。

---

## 1. customer-merge-design.md（P4-4 顧客名寄せ → R6・未実装）

### 主な改訂内容
- 改訂ヘッダ追加（R6・未実装。前提のマイページ認証は R4 実装済み）。ステータス行を「Q-11〜13 は D-12（2026-07-26）で本書推奨どおり決定済み・実装は R6 未着手」に更新。
- §0 前提事実を Rails 現行実装で全面再突合（表に「Laravel設計時からの差分」列を追加）: `Customer`（Devise database_authenticatable/lockable/timeoutable、`:rememberable` 不使用→`remember_token` 不在）、`customers.email` unique+nullable / `encrypted_password` not null default ""、`stores` FK cascade / `orders` FK restrict / `applications` FK nullify、`inquiries.order_id`、`inquiry_message_recipients` / `notification_recipients` / `system_notifications` のポリモーフィック宛先＋静的メール保持、`AuditLog`（activitylog→`user_type/user_id`・`resource_type/resource_id`）、`OtpAuthenticatable`（10分/5回）、rack-attack、Solid Queue、Pundit `AgencyScoped`。
- §1-1 画面/実装物を Hotwire+ERB に読み替え（`Mypage::MergeKeysController` / `Mypage::CustomerMergesController#new/confirm/create` / `CustomerMergeMailer` / `CustomerMergeService`）。
- §1-2 移管トランザクションを Ruby 擬似コードに書き換え: `ActiveRecord::Base.transaction` + `Customer.where(...).order(:id).lock`、`update_all` 条件付き消費（戻り値1件チェック）、`update_all` 一括移管（Auditable を通さない意図と R2 の `strip_ownership_params!` との関係を注記）、`encrypted_password=""` による無効化と Devise `authenticatable_salt` 変化による全セッション自動失効、`AuditLog` 直接記録。**代理店またぎ統合時に `OrderPolicy::Scope`（orders.agency_id）と `StorePolicy::Scope`（customer.agency_id）の絞り方が異なり参照非対称が生じる**点を新規注記。stores/orders INSERT が customers 行ロックで止まらない余地も注記（要検討）。
- §2 データモデル: PostgreSQL partial unique index（有効キー1顧客1本）、`Auditable::TRACKED_FIELDS` 追加、`performed_by_type/id`（顧客本人 / 管理者主導）列を追加、`CustomerMergePolicy` の staff 限定閲覧。
- §3 Q-11〜13: artisan→rake `customer:unmerge[merge_id]`、`config/customer_merge.php`→`config/customer_merge.yml`、P5-7→R8、Q-12 の Rails版無効化手順を明記。
- §4 統合対象外: R4 実装済みの Inquiry 統合・`inquiry_message_recipients` 追加・`applications` は移管対象と明記。
- §5 セキュリティ: rack-attack throttle・`filter_parameter_logging`・email nil 顧客の発行不可・Pundit 二重防御（§5-8 新設）。
- §6 移行名寄せ（R7）: R5 の新テーブル（payment_transactions 等）が customer FK を持つ場合 `CustomerMergeService::MOVABLE_ASSOCIATIONS` に追加するチェック項目を追記。
- §8 新設: **request spec 必須事項 S-1〜S-8**（行ロック / TOCTOU / ワンタイム消費 / 代理店またぎ検知 / ロールバック / 退会後ログイン遮断 / 認可 / 監査）。

### 現行実装との差分・未実装事項
- 本機能は全面未実装（R6）。テーブル `customer_merge_keys` / `customer_merges`、サービス、コントローラ、メーラー、rake、recurring prune すべて新規。
- Laravel設計との実装差: `remember_token` 不在 → `encrypted_password` 空文字化で代替（Devise セッション失効を兼ねる）。

### 04 反映事項
- R6 顧客名寄せ: 本書 §7 の実装物一覧（a〜f + 定期削除）と §8 S-1〜S-8 を R6 完了条件へ（優先度: 中。P4-9 マイページ拡充と同時設計）。
- R5 スキーマ設計チェック項目: 「顧客 FK を持つ新テーブルは `CustomerMergeService` の移管対象に追加」（出典 §6-2）。
- 要検討: 「withdrawn 顧客への Store/Order 新規紐づけを拒否するバリデーション」（出典 §1-2 失敗点表）。

### 決定者/業務側 未決論点
- 代理店をまたぐ統合を許可するか（本書は「許可＋履歴で検知」を暫定。参照非対称の説明を添えて要確認）。
- 退会顧客の PII 保持期間ポリシー（Q-12 派生。R8 法務と一体）。

---

## 2. export-profile-design.md（P4-12 CSV複数プロファイル → R6・未実装。基盤は R2/R4 実装済み）

### 主な改訂内容
- 改訂ヘッダ追加。ステータス行を「Q-14 は D-13 で本書推奨（config 管理 v1）どおり決定済み・実装は R6 未着手」に更新。
- §1-1 を **Rails版の現状分析**に全面差し替え: トリガー `Admin::{Customers,Orders}Controller#export`（`button_to`・検索条件は引き継がれない）、`CsvExportJob::EXPORT_TARGETS`（Customer/Order 固定列・`Pundit.policy_scope!`・`Current.user`）、`CsvExport`（`resource_type` / `file_data` text 直保持 / `filters`・`expires_at`・定期削除なし）、`Admin::CsvExportsController#show`（BOM なし・サニタイズなし・ファイル名固定）、`CsvExportPolicy`（本人 or staff）、`csv_download_visible`（R1 列のみ・未接続）、既存 spec 3 件。
- §1-2 制約箇所を Rails版 7 項目に更新（Store 未対応・成果物 DB text 肥大化を追加）。
- §2 を YAML（`config/csv_export_profiles.yml`）+ `CsvExportProfile` 値オブジェクト + `CsvExport::Catalogs/Sources/Writer` + Hotwire ドロップダウンに読み替え。暗号化列のカタログ除外を spec で禁止（R3 `allowed_target_columns_for` と同思想）。PII 列を含む DL の `AuditLog` 記録を追加。
- §3 比較表を Rails版で見直し: Laravel設計時の「P2-1 FormTemplateDefinition と同型（コード定数）」根拠は **R3 でフォーム定義が DB 化されたため不成立**。「カタログ=コード／定義=DB」（案C）が R3 と完全同型である点を明記し、v1=A・A→C 昇格容易な構造を受け入れ条件に。
- §4 実装ステップ: **P4-1 順序制約は R1 で解消済み**（現行 Job が既に policy_scope! 経由）。Step 8（Store プロファイル）・Step 9（請求用受注データ移設）を新設。定義単位権限は `CsvExportProfilePolicy`（Pundit）+ `csv_download_visible` 接続を推奨。
- §6 未決事項に BOM 付与・成果物保存先（text vs Active Storage）・`csv_download_visible` 意味づけを追加。
- **§7 新設: R5 D-P8 請求用受注データCSVの位置づけ** — 3 案比較のうえ「R5 で `EXPORT_TARGETS` に `BillingOrder` を先行追加（staff 限定・列は TBSS ヒアリング後確定・spec 先行）→ R6 Step 9 で YAML プロファイルへ移設」を提案（`payment-integration.md` §4-8 の Rails版注記と整合）。

### 現行実装との差分・未実装事項
- 実装済み（R2/R4）: Customer/Order の固定列非同期エクスポート＋policy_scope 絞り込み＋本人限定DL。
- 未実装（R6）: 複数プロファイル / 列カタログ / 絞り込み引継ぎ / CP932・CRLF・BOM・サニタイズ / 定義単位権限 / Store / expires_at＋定期削除 / Turbo でのステータス更新。
- 未実装（R5 提案）: `BillingOrder` エクスポート。

### 04 反映事項
- R5 節「請求用受注データCSV出力の実装先を確定する」→ **確定案: R5 で `EXPORT_TARGETS` に `BillingOrder` を先行追加、R6 で本設計 Step 9 に移設**（出典 §7。優先度: 高＝稼働後最初の月次請求が締切）。
- R6 CSV汎用化タスクの分解: Step 1〜6 基盤（Q-15 非依存）/ Step 7 アシスト納品（Q-15 後）/ Step 8 Store / Step 9 請求用移設（出典 §4）。
- R6 に BOM 既定・成果物保存先・`csv_download_visible` 意味づけの 3 決定事項を追加（出典 §6）。

### 決定者/業務側 未決論点
- Q-15 アシスト納品フォーマット（ヒアリング回答待ち・D-10）。
- 請求用CSVの列定義（payment-integration.md 論点14・TBSS ヒアリング）。
- CSV 既定文字コードを UTF-8 BOM 付きに変えるか。

---

## 3. business-flow-analysis.md（業務フロー93スライド分析 → 横断 R2/R5/R6/R7）

### 主な改訂内容
- 改訂ヘッダ追加。§0〜§2・§5〜§8・§10 に Rails版の対応（section 3区分・R フェーズ・カラム名）を注記。業務事実は変更なし。
- **§3-1 判定変更**: Laravel版は全35ステータスをシード済みだったが、Rails版 `StatusSeeder::ORDER_STATUSES` は **5 値のみ**（`0:受注` `10:作業進行中` `21:解約` `22:強制解約` `100:CLOSE`）。資料の15値等が未投入 → **新規差分 G-10** として §9-2 に追加（R5 前・§3-3 統廃合後コード表で投入）。
- §3-2 Q-B: D-8 決定済みだが `customer_statuses` 側の表示が未適用（04 R2 追加タスクと整合）。
- §4 掲示板: **R4 で Inquiry 統合済み**（`Inquiry::CATEGORIES` 4種・`InquiryStatus`・`InquiryRecipientRoute`・投稿者は `created_by_id`）。差分は 2,000 文字上限のみ（要否確認）。
- §5-2/5-3: `form_fields.required` boolean のみ（3段階は R5）、おまとめ請求列は R2 済・フォーム分岐は R5、架電時間は自由入力（締切ロジック R5）、属性1〜11 は受け皿列＋`OptionGroup` 機構あり・データ投入とフォーム連携未、SNS 認証情報 8 列＋billing_password は暗号化済み。
- §6-1: 1案件=1プラン=1商材のモデル（`Order.plan_id`→`Product`）では「2商材独立進行・両方揃って検収」を表現できない旨を明記（G-1/G-9 の根）。
- §7: R5 D-P8 請求用CSVとの関連を冒頭に注記、7-1 に Rails カラム対応表、7-2 に `contract_conditions` が期間/違約金を持たない旨（R5 要確認）、7-3 に Q-24 確定済み・未収情報は 04 R2 追加タスクを注記。
- §8 に「Rails版フェーズ」列を追加（#12 ガルーンを追加）。
- **§9-2 に「Rails版判定」「R フェーズ」列を追加**（下表）。
- §11 に development-plan §8 の決定状況（D-3保留 / D-8 / D-11 / D-4 / D-9）と 04 の該当箇所を付記。**Q-H の採番衝突**（development-plan §8 の Q-H は「ステップ配信」）を注記。

### G-1〜G-10 の Rails版判定表（04 反映用）

| # | 内容 | Rails版判定 | 根拠 | R フェーズ |
|---|---|---|---|---|
| G-1 | 商材別の納品日 | **未対応** | `orders.work_completed_at` 単一 date 列。Q-F（D-4: 別テーブル化）がスキーマ未反映。1案件=1商材モデルで「2商材独立進行」を表せない | **R5 前**（検収遷移条件に直結） |
| G-2 | 掲示板4種 | **R4 対応済み** | Inquiry 統合（D-11） | R4 済 / R7（アーカイブ・Q-44） |
| G-3 | 必須3段階の入力チェック | **未対応** | `form_fields.required` boolean のみ | R5（P3-10） |
| G-4 | 属性1〜11 選択肢マスタ | **一部対応** | `OptionGroup/OptionValue`＋`attribute_1..11` 列あり。選択肢データ投入と FormField→OptionGroup 連携なし（`input_options["choices"]` 直書き） | R3 追補 or R7 |
| G-5 | 一括コピー・自動入力依存 | **未対応** | FormField/Stimulus に該当機構なし | R6 |
| G-6 | 架電時間の受付締切 | **未対応** | `confirm_call_time` 自由入力 string | R5 |
| G-7 | 会員情報と作業項目の同期 | **一部対応** | R3 動的マッピングで入力は一本化。スキーマ重複列（例 `customers.num_employees` vs `order_work_details.num_employees`）は残存 | R6 |
| G-8 | 進捗遅延の検知 | **未対応** | 04 R6 記載のみ。recurring＋SystemNotification の下地は R4 | R6 |
| G-9 | 商材ごとの作業完了日 | **未対応** | G-1 と同根 | R5 前 |
| G-10（新規） | 案件ステータス全35値のシード | **未投入** | `StatusSeeder` 5 値のみ | **R5 前** |

### 04 反映事項
- R6「業務フロー資料の差分G-1〜G-9の反映状況確認」→ 上表で確認完了。**G-1/G-9/G-10 は R5 前ブロッカー**として R5 着手前チェックリストへ移す（出典 §3-1・§9-2）。
- R5 要確認: `contract_conditions` に最低利用期間・更新周期・違約金を持たせるか（出典 §7-2）。
- R4 後続/R6: Inquiry 本文 2,000 文字上限の要否（出典 §4）。
- Q 採番: 本書 Q-H（属性選択肢の Google 仕様追随）は development-plan §8 の Q-H（ステップ配信）と衝突 → **Q-H2 等へ再採番**（出典 §11）。

### 決定者/業務側 未決論点
- G-1 の解決方式（案件を商材ごとに分割 vs `order_deliveries` 別テーブル）— D-4 は「別テーブル化」だが 1案件=1商材モデルとの整合を要確認。
- Q-A（D-3 保留）、Q-D（SNS 認証情報の保持可否）、Q-E（アイフラッグ API）、Q-G（ステータス実運用）、Q-G2（ガルーン・D-9 保留）、Q-H（属性選択肢追随）。

---

## R6 タスク分解案（優先度付き・04 反映用）

| 優先度 | タスク | 出典 | 前提/備考 |
|---|---|---|---|
| **高（R5 前に前倒し）** | 案件ステータス全値シード投入（G-10）＋G-1/G-9 の納品日別テーブル化方式決定 | business-flow-analysis §3-1・§9-2 | R5 契約ワークフローの遷移条件に直結 |
| **高（R5 内で先行）** | `EXPORT_TARGETS` に `BillingOrder` 追加（請求用受注データCSV。staff 限定） | export-profile-design §7 / payment-integration §4-8 | 列は TBSS ヒアリング後。締切＝稼働後最初の月次請求 |
| 高 | CSV 汎用化 Step 1〜6（プロファイル YAML・Writer・トリガー集約・汎用 Job・絞り込み引継ぎ・定義単位権限）＋Step 8 Store | export-profile-design §4 | Q-15 非依存。既存 spec 3 件の回帰維持 |
| 中 | CSV 汎用化 Step 7 アシスト納品プロファイル / Step 9 請求用移設 | export-profile-design §4・§7 | Q-15 確定後 / R5 完了後 |
| 中 | 顧客名寄せ（customer_merge_keys / customer_merges / Service / mypage UI / Mailer / rake unmerge / prune）＋ spec S-1〜S-8 | customer-merge-design §7・§8 | P4-9 マイページ拡充と同時設計。代理店またぎ許可の業務判断が先 |
| 中 | 遅延検知・自動キャンセル（G-8。recurring＋SystemNotification。閾値は §1-3 リードタイム） | business-flow-analysis §1-3・§9-2 | 通知マトリクス E8 と連動 |
| 中 | CustomerStatus/OrderStatus 遷移バリデーション（04 既載） | business-flow-analysis §1-2 | G-10 投入後 |
| 低 | G-5 フォームビルダー拡張（コピー/依存）、G-7 スキーマ重複列の正規化ルール、Inquiry 2,000 字上限要否、CSV BOM 既定・成果物保存先・`csv_download_visible` 意味づけ | 各書 | 個別判断 |

---

<!-- ===== summary-G-release-devplan ===== -->

## サマリ G: release-readiness.md / development-plan.md（R8・全体計画）Rails版改訂

突合日 2026-08-19。編集ファイル: `requirements/design/release-readiness.md`（258行）、`requirements/development-plan.md`（445行）。git 操作なし・他ファイル未編集。

---

## 1. `requirements/design/release-readiness.md`

### 主な改訂内容
- 冒頭に改訂ヘッダ＋**「基盤スタックの正は 03§2／§8」**を明記。旧Laravel決定（MySQL 8.4 / Redis+Horizon / Reverb / SES・S3前提 AWS 構成 = 削除済み `basic-cost.md`）は「Laravel側限定の旧決定」として置換。
- 状態ラベル凡例（✅実装済み／🔶部分実装／⬜未着手（R8）／❓要決定+Q番号）を新設し A〜J 全項目に付与。
- **A（インフラ）**: A-1 を「MySQL 8.4 → 廃止、03決定A PostgreSQL 16（+pg_bigm）・primary/cache/queue/cable 4DB構成」へ。A-3 を現行 CI 実態（brakeman/bundler-audit/importmap audit/rubocop/rspec on PostgreSQL 16 コンテナ/authorization_guard の5ジョブ・デプロイ自動化なし）へ。A-4 credentials/`RAILS_MASTER_KEY`/`.kamal/secrets`、A-5 TrustProxies→`RemoteIp`/`assume_ssl`（IP許可リストと AuditLog が `remote_ip` 依存）、A-6 Solid Queue（`queue.yml`・recurring・`SOLID_QUEUE_IN_PUMA`）、A-7 Solid Cable、A-8 Active Storage local、A-12 SMTP 未設定（`default_url_options` が example.com）、A-13 Kamal 雛形（宛先 192.168.0.1 のまま）・採否未定、**A-14（新）Ruby 3.3.4 vs 03記載3.4 の差異**。
- **B（移行）**: R7 として保持。ETL は rake、`contract_condition_id` が orders 側、Rails スキーマへの読み替えを注記。
- **C（セキュリティ）**: C-2 CI 組込済み、C-3 OrderWorkDetail 暗号化済み/Customer PII 方針未記録、C-6 rack-attack が `/users/*` のみ（form/mypage 未適用）、C-7 IP許可リスト+全画面OTP 実装済み、C-10 権限昇格監査済み、**C-13（新）セッション/Cookie ハードニング（force_ssl・expire_after・reset_session・config.hosts）**、**C-14（新）ログマスク済み**。
- **D（決済・契約）**: R5 未着手として要件全保持。D-6 は Q-24/D-P8 決定反映。**D-8（新）決済専用キュー・リトライ無効化、D-9（新）会員ID引継ぎ**。
- **E（監視）**: STDOUT ログ・`/up`・Solid Queue テーブル、ダッシュボード（mission_control-jobs）未導入、E-4 は 4DB のバックアップ対象整理、**E-10（新）監査ログ検索/CSV 画面未**。
- **F（テスト）**: 現状を RSpec 38 ファイル内訳へ更新。F-3 参照制御は R1/R2 でカバー（通知宛先/問い合わせ/マイページは未）、F-9 CI は PostgreSQL 16 で稼働（migrate/rollback smoke 未）、**F-10（新）`verify_authorized` 未導入**。
- **G〜J**: R8 として保持。削除済み `remaining-tasks.md` 8-1/8-2/6-1 の内容は本文に保持。H-1（マニュアル）・H-2 は「04 に対応タスク無し」と明記。**I-6（新）初期データ投入（OptionGroup/BRIDGE_PLUS テンプレ/FAQ 未）**。J-2 Store 一覧のみページネーション無し。
- マイルストーンを M1（R0〜R4 達成）／M2（R5）／M3（R8+R7）へ。変更履歴に本改訂を追記。

### 現行実装との差分・未実装事項（フェーズ付き）
| 項目 | 状態 | フェーズ |
|---|---|---|
| Ruby バージョン（03: 3.4 / 実態 3.3.4） | 要整合 | R8 A-14 |
| `force_ssl`/`assume_ssl`/`config.hosts`/`expire_after`/form ログイン時 `reset_session` | 未実施 | R8 C-13（本番前必須。R5 前でも可） |
| rack-attack スロットルが `/users/password` `/users/otp*` のみ。`/form/otp` `/form/login` `/mypage/otp` `/mypage/login` `/users/sign_in` は未 | 未実施 | R5 前小改修 or R8 C-6 |
| `verify_authorized`/`verify_policy_scope` 未導入 | 未実施 | R5 前推奨 F-10 |
| SMTP 本番設定・`default_url_options` | 未設定 | R8 A-12 |
| デプロイ方式（Kamal 採否）・本番構成・ステージング | 未決 | R8 Q-40/42/43 |
| Solid Queue ダッシュボード（mission_control-jobs）・失敗ジョブ運用 | 未導入 | R8 A-6/E-7 |
| CI migrate→rollback→migrate smoke | 未 | R8 F-9 |
| 監査ログ全件検索/CSV 画面 | 未 | R6 E-10 |
| 初期データ投入（OptionGroup 属性1-11・BRIDGE_PLUS テンプレ・FAQ） | 未 | R7/R8 I-6 |
| Store 一覧の検索/ページネーション/CSV | 未 | R6（04 R2 見送り事項） |

---

## 2. `requirements/development-plan.md`

### 主な改訂内容
- 役割を「**全体像・P→R 対応表・未決定事項台帳・変更履歴**」に再定義。フェーズ詳細の正は 04 と明記（更新ルールも「まず 04 に書く」へ変更）。
- §0 ドキュメント体系: 削除済み 7 ファイル＋`impl-plans/` を除去し「削除済み（旧Laravel側残存）」注記へ。Rails 版体系（01〜04・review/・各設計書・legacy-research/）に更新。
- §1 システム概要: システム名「未定・仮称 brige-crm」、Rails スタック・gem・認証3系統（Devise User / Form 独自セッション / Devise Customer + 全画面 OTP + IP許可リスト）・2層認可・監査を記載。
- §2 現状サマリ（2026-08-19）: R0〜R4 の実装内容を `app/` 実態から要約（モデル/コントローラ/サービス/ジョブ名）。未実装一覧を R フェーズ付きへ。T-1〜T-6 の Rails 版状態（T-1/2/3/6 解消、T-4 持ち越し、T-5 該当なし）＋新規 **T-7〜T-11**（Ruby 版差異／Q-B 中途適用／セッション強化／rack-attack 範囲／verify_authorized）。「MySQL 8.4 決定」節を「PostgreSQL 置換」節へ。N-1（カットオーバー当日作業）は全文保持し R7/R8 へ紐付け。basic-design 1〜7章突合表を R 読み替え。
- §3: R0〜R8 概要表（04 準拠・状態付き）を主とし、**P0〜P5 の各タスク→R 対応表**を新設。04 未反映タスクに ⚠️ を付与。
- §4〜§6: R 基準の依存関係・優先度・進捗へ。
- §7: 「ftlog 直接移植・R0/R4 実装済み」へ（remember me 抜け穴は `rememberable` 不採用で構造上発生しない、TrustProxies は R8 必須、通知テーブル分離済み）。
- §8: **全 Q（Q-1〜44・Q-A〜H・Q-背・Q-移）を保持**し「状態／R・04 参照／備考」列を追加。Q-25〜27・Q-35〜39 を「R5 着手前ブロッカー」として 04 と番号を揃えた。
- §9: 履歴保持＋brige-crm 側の 08-14/08-15/08-18/08-19 と本改訂を追記。

---

## 3. 04-rails-implementation-plan.md へ反映すべき事項（フェーズ・優先度・出典）

### 3-1. Laravel P 番号のうち 04 に未反映のタスク一覧（推奨 R フェーズ付き）
| P | 内容 | 推奨 R | 優先度 | 出典 |
|---|---|---|---|---|
| P2-3 | `form-template-mapping.md` §7 #5〜7 未決定事項の確定 | R3 後続（155項目突合と一体） | 中 | development-plan §3-2 |
| P2-5 / P4-5 | OptionGroup 初期データ（属性1-11 等・`legacy-research/05` §4）の投入手段。`db/seeds.rb` は RoleSeeder/StatusSeeder のみ | R7（初期データ）or R8 I-6 | 中 | 同上 / release I-6 |
| P2-6 / P2-8 | BRIDGE_PLUS フォームテンプレート定義（155項目）の投入。UI は R3 済み | R3 後続 / R7 | 高（R5 の申込→決済導線に必要） | 04 R3 要確認の拡張 |
| P4-6 | 案件検索へのメールアドレス条件追加（現状 `order_number` ILIKE のみ） | R6 | 低 | §3-2 |
| P4-7 | ユーザ無効化の運用整理（物理削除との役割分離・固定権限・セッション失効） | R6 | 中 | §2 basic-design §1 |
| P4-9 | マイページ機能拡充（R4 は最小構成） | R6 | 中 | §3-2 |
| P4-11 残 | お纏め請求・備考・予備欄（未収情報は 04 R2 に記載済み） | R6 | 低 | §3-2 |
| P4-16 残 | 監査ログ全件の検索/CSV 画面＋R5 必須監査イベント一覧（契約/決済/署名/重説/契約書生成） | R6 / R5 | 中 | release E-10 |
| P4-21 | 連携状況記録＋連携エラー時の自動アウトバウンドメール | R6 | 中 | `legacy-research/04` 51-52 |
| P4-23 | GBP アカウント権限管理・受注完了経過管理 | R6 | 中 | 同 34-35 |
| P4-24 | 対応音声ログ管理（容量・法務要確認。P3-7 確認コールと連動） | R6 | 中 | 同 64 |
| P4-26 | 初回運用レクチャー管理 | R6 | 低 | 同 36 |
| P4-27 | KW 管理（P3-11 とは別） | R6 | 低 | 同 38 |
| P4-28 | 代理店管理画面での資料共有フル版（SalesMaterial は R2 済み） | R6 | 低 | 同 46 |
| P4-29 | 顧客利用停止（退会）と退会済み表示/検索（Q-34） | R6 | 中 | basic-design §5-3 |
| P5-4 | システム利用マニュアルの Web 提供＋生成の仕組み（Q-20 顧客まで全対象。ftlog 移植） | R8 | 中 | release H-1 |
| P5-6 | 情シスへのリスク連携（本番構成・DNS/メール・DB/ストレージ・監視・PII・ガルーン）を R8 に明示 | R8 | 高（リードタイム） | release G-2 |
| P5-8 | バックヤード作業マニュアル | R8 | 低 | release H-2 |
| P5-10 | セキュリティ診断（外部脆弱性診断・PCI DSS・PII ゲート・シークレット・アクセス制御）を R8 の完了条件に明示（現行は「UAT/性能診断」のみ） | R8 | 高 | release C |
| P5-13 | 月次レポート作成・送付（内製 or 外注の別意思決定と連動） | R6 or スコープ外判断 | 低 | `legacy-research/01` §4-1 |

### 3-2. Rails 版突合で新たに判明した追加タスク
| 内容 | 推奨 R | 優先度 | 出典 |
|---|---|---|---|
| rack-attack スロットルを form/mypage の OTP・ログイン、`/users/sign_in` へ拡張（現状 `/users/password` `/users/otp*` のみ） | R5 前小改修（or R8 C-6） | 高 | release C-6 / T-10 |
| セッション/Cookie ハードニング一式（`force_ssl`・`assume_ssl`・`config.hosts`・`expire_after`・form ログイン時 `reset_session`）を「本番前必須」として R8 に明記（04 R3 見送り事項の格上げ） | R8（本番前必須） | 高 | release C-13 / T-9 |
| `after_action :verify_authorized`/`verify_policy_scope` 導入（04 R0 見送り事項）を R5 着手前チェックリストに追加 | R5 前 | 中 | release F-10 / T-11 |
| Ruby バージョン整合（`.ruby-version` 3.3.4 vs 03§2「3.4」）。3.4 へ上げるか 03 を 3.3 に訂正 | R8 | 低 | release A-14 / T-7 |
| CI に `db:migrate`→`db:rollback`→再 `db:migrate` smoke を追加 | R8 | 低 | release F-9 |
| Solid Queue ダッシュボード（`mission_control-jobs`）導入要否・失敗ジョブ運用手順 | R8 | 中 | release A-6/E-7 |
| 決済専用キューの `queue.yml` worker 分離＋`retry_on` 不使用を R5 設計項目に明記 | R5 | 高 | release D-8（payment §4-2） |
| 本番構成方式（Q-40）・デプロイ方式（Kamal 採否・`config/deploy.yml` 宛先/registry 仮値）・SMTP/`default_url_options`・Active Storage 保存先を R8-A の決定項目として列挙 | R8 | 高 | release A-3/A-8/A-12/A-13 |
| 参照制御の横断テスト拡張（通知宛先検索・問い合わせ宛先解決・マイページの代理店スコープ） | R6 or R8 | 中 | release F-3 |
| `basic-cost.md` 削除に伴う PostgreSQL/Redisレス構成での費用再試算＋構築手順書作成 | R8 | 中 | release A-11 |
| PII 分類A（Customer 本体）を暗号化しない方針の正式決定記録（Q-D） | R5 着手前 | 中 | release C-3（04 R2 見送り事項の再掲） |

### 3-3. §8 未決 Q の一覧と状態（04 反映用）
- **R5 着手前ブロッカー（04 チェックリストと番号一致）**: Q-25 返金/キャンセル、Q-26 信販、Q-27 決済障害縮退、Q-35 重説/確認書、Q-36 決済紐づけ単位、Q-37 jutyu_cd 桁数、Q-38 決済結果確定手段、Q-39 ステージング決済検証。加えて Q-D（PII 方針記録）・Q-B（呼称統一の実装完了）。
- **R5 で決める**: Q-7 支払方法、Q-8 署名手段、Q-29 電子契約統合、Q-33 料金非表示と checkout 表示の整合、Q-32 入力端末/URL 受渡（R3 実装は営業端末前提）。
- **R6**: Q-6 顧客重複時運用、Q-15 アシスト納品フォーマット（起案承認済み・未決）、Q-28 外部ツール代替、Q-31 代理店ログインメール、Q-34 通常退会、Q-E AI投稿代行自動化、Q-H ステップ配信、Q-G2 ガルーン（情シス保留）、Q-背1〜4。
- **R7**: Q-44 掲示板アーカイブ運用要件、Q-移1〜5（+04 の Q-移7/15/18・DM-7）。
- **R8**: Q-1 リリース時期、Q-2 段階/一括、Q-3 体制、Q-10 カバレッジ目標、Q-40 本番構成、Q-41 バックアップ/RTO/RPO、Q-42 ドメイン/TLS、Q-43 ステージングデータ種別、Q-A PII ルール（保留 D-3）。
- **決定済み・実装済み**: Q-4, Q-11〜13, Q-14, Q-16, Q-17, Q-19, Q-22, Q-23, Q-24, Q-C。**決定済み・未実装**: Q-18 メンション（R6）、Q-20 マニュアル（R8・04 未反映）、Q-F 納品日別テーブル（R5/R6・G-1）。**決定済み・実装中途半端**: Q-B（T-8）。
- **構造上解消**: Q-9（NestedSet 不採用。ただし「グループ兼代理店」の業務要件は要確認）。Q-30 は実装（PW なし＋OTP）と basic-design §2-1 が矛盾のまま。

---

## 4. 決定者/業務側の確認が必要な未決論点
1. **R5 着手前ブロッカー** Q-25〜27・Q-35〜39（04「次のアクション」5 と同じ）。
2. **Q-B**: `customer_statuses` の表示を「申込ステータス」へ統一するか（T-8）。
3. **Q-D**: Customer 本体 PII（分類A）を暗号化しない方針の正式決定。
4. **本番構成・デプロイ方式（Q-40）と Kamal 採否**、ドメイン/TLS（Q-42）、SMTP プロバイダ（SES 継続か）— 情シス連携（W-4/G-2）と一体。リードタイムが長いため R5 と並行で着手したい。
5. **W-5**: リクリックとのカットオーバー当日作業合意（N-1-a）。リリース日（Q-1/Q-2）の前提。
6. **Q-30**: 受注入力にパスワード再設定を持たせない現実装で確定してよいか（basic-design §2-1 側を改訂するか）。
7. **Q-9 の業務側**: 「グループ兼代理店」を単一所属（agency_group_id or agency_id）で表現してよいか。
8. **P5-13 月次レポート**と **P4-24 音声ログ**（法務・容量）はスコープに含めるか。
9. **Ruby 3.4 へ上げるか 3.3 系で固定するか**（03§2 との整合。軽微）。

---

<!-- ===== summary-H-legacy-1 ===== -->

## サマリ H-legacy-1: legacy-research/00〜08 Rails版改訂（2026-08-19）

対象: `requirements/design/legacy-research/00-index.md` 〜 `08-data-migration-source.md`（9ファイル）。
方針: 調査事実（旧システム仕様・数値・ヒアリング・API仕様・依頼書番号）は一切改変せず、「新システム側の対応先」記述のみ Rails 版（brige-crm）へ差し替え、`db/schema.rb`・`app/models`・`app/services/status_seeder.rb`・`app/controllers/admin/*` と突合して実装状況（R0〜R4 実装済み／R5・R6 未実装／R7 で扱う）を明記。各ファイル冒頭に改訂ヘッダ、末尾の変更履歴に 2026-08-19 行を追加。章番号は維持。

## ファイル別 主な改訂内容

| ファイル | 主な改訂 |
|---|---|
| 00-index.md | §1 表を「内容／調査／主なRフェーズ／実装状況・改訂状況」に拡張（`15-test-purchase-20260728.md` を追加。09〜15 は並行改訂と注記）。§1 末尾に R7 持ち越し未決事項を集約。§3 に brige-crm 用語、§4-2「新システム（brige-crm）での位置づけ」表を追加。★1/★2 に R5/R7 併記 |
| 01-background-and-goals.md | §2-1 現行課題7件に「brige-crm 実装状況」列（RBAC/マイページ/通知 = R0/R4 済み、入力チェック・顧客本人入力・音声ログ = R5/R6 未実装）。§3/§4 に `Plan`・`Product`・`orders.bridge_*` 列の R2 実装状況、§5 論点に R フェーズ列 |
| 02-payment-netmove.md | API仕様は不変。PHP `hash_hmac` → `OpenSSL::HMAC` + `secure_compare`、VerifyCsrfToken except → `skip_forgery_protection`、`string('jutyu_cd',12)` → `t.string :jutyu_cd, limit: 12`、`PaymentTransactionStatus` → `PaymentTransaction#status`（手実装状態機械）、リトライ禁止 → Solid Queue 決済専用キュー。§7-b「brige-crm での実装状況と対応先」を新設（決済系 R5 未実装／`customers.netmove_member_id`・`sms_mobile_number`・`orders.bundled_billing` 等は R2 済み）。Q-37/Q-38 が 04 R5 チェックリスト管理中と注記。詳細は payment-integration.md 参照とのみ記述 |
| 03-legacy-status-and-boards.md | 掲示板4種→`Inquiry`/`InquiryStatus`/`InquiryRecipientRoute`（R4 済み）の対応表。§2-1 セット操作に実装状況列（受け皿カラム R2 済み／遷移連動 R5・R6 未実装）。§3 `SampleDataSeeder` → `StatusSeeder`（最小セット）へ差し替え、**`orders.status` 既定値 `0:受注` と精査「受注削除」の食い違いを要確認として明記**。`ftlog-port.md` 削除済み差し替え。反映先表に R フェーズ列 |
| 04-requirements-inventory.md | 機能64件（§1-1）、大平要望（§2）、TBSS要望（§3）、P4-18〜25（§4）に brige-crm 実装状況列。案件検索メール条件（14）は未実装と確認（現行検索は order_number/status のみ）。`remaining-tasks.md` 削除済み差し替え（未収情報は 04 R2 追加タスクへ拾い上げ済みと注記）。P4-25 を §4 表へ追加 |
| 05-legacy-spec-fields.md | `jasmin_orders` → `orders`、`FormTemplateDefinition` → `FormField`（`editable_by_tier` 配列 / `lock_after_status` / `locked_for?`。R3 済み）。システムアカウントID/PASS → `order_work_details.system_account_*`（encrypts）。§2-1 新規フィールドの実装有無突合（ファクター回収備考 `factor_notes`・履歴記載枠 `operation_history` = 済み／伝票番号(発送/返送)・店舗メール・サイン画像 = 未実装）。添付（Active Storage 50MB/合計制限なし）、`OptionGroup`（選択肢シーダー未作成）、掲示板ルーティング（転送先13件の初期データ未投入）を追記 |
| 06-bw-operations.md | 各表に R フェーズ・実装状況列（アフター掲示板 R4 済み、他 R6 未実装）。§3 ガルーン連携を R6・Solid Queue ジョブ想定に。§6 未読リストを 13/14 参照付き履歴に |
| 07-plans-and-billing.md | `Plan`（`is_active` = 新規受付可否）/`ProductInitialFee`/`ContractCondition` の R2 実装状況。**月額料金スナップショット列が無い（Q-移15）**、契約期間・違約金ロジック未実装（R5）、Q-移18 の R7 持ち越し |
| 08-data-migration-source.md | 対応先を Rails 実テーブルへ差し替え（`organizations`/`jasmin_stores` 除去、`agency_groups`/`agencies`/`sales_representatives`/`stores`/`inquiries`）。`stores`・`agencies` 実カラム記載、Q-移7 注記。DM-1〜8 に状態列（Q-C 決定済み、`SequenceCounter` 採番、`orders.serial_id`/`bridge_migration_order_number` が旧番号保持列、DM-6/7/8 持ち越し）。§4 に R7 位置づけ（決定F・rake/`rails runner`） |

## 現行実装との差分・未実装事項（フェーズ付き）

- **R5 未実装**: PaymentTransaction/決済状態機械/HMAC/ret_url 受け口（02）、入力チェック設定・不備チェック・差戻し・確認コールのフロー化（01/03/04）、契約書PDF・サイン画像（04/05）、顧客本人による入力導線（01 #4）、契約期間・違約金・継続課金・請求（07）、`lock_after_status` を効かせる再編集フロー（05）
- **R6 未実装**: P4-18〜25（遅延検知・自動キャンセル・集計・連携記録・外部CSV取込・GBP管理・音声ログ・ガルーン連携）、案件検索メール条件（P4-6）、ステータス遷移バリデーション、FAQ返信テンプレート（R4後続/R6/R7 未定）
- **R7**: 移行ETL全般、掲示板42万件（参照アーカイブ）、旧プランの `is_active: false` 投入、`OptionGroup` 選択肢・転送先13件・`RecipientGroup` の初期データ投入、旧番号保持・採番開始値
- **実装が旧設計と異なる点（実装を正として追従）**: 添付は Active Storage で1ファイル50MB・合計制限なし（現行 3MB/5枠・合計10MB より緩い）／`StatusSeeder` は order_statuses 最小5件のみ（現行37件全件移植せず）／`agencies` に住所・電話なし／`stores` にメール列なし

## 新スキーマと矛盾する記述の有無（04 R7 反映用）

致命的矛盾なし（review-05 §6 と同じ結論）。ただし以下は「食い違い・要確認」として各ノートに明記した:
1. **`orders.status` 既定値 `"0:受注"`（`OrderStatus::CODE_ORDERED`・is_system・削除不可）vs 浅賀精査「受注(0)は不要・削除、インポート時は空欄」**（03 §3・08 DM-6）。R5 状態機械／R6 遷移バリデーション／R7 マッピングのいずれかで「申込直後の初期状態コード」を決める必要あり。実装を正とするなら「受注＝新システムの初期状態（旧の受注(0)・空欄→初期状態にマップ）」と再定義。
2. `orders` に月額料金スナップショット無し（07。Q-移15）
3. `agencies` に住所・電話無し（08。Q-移7）
4. `stores` に店舗メール無し／管理者メール「;」区切り複数の受け皿無し（05 §2-1）
5. 伝票番号（発送用/返送用）の受け皿無し（05 §2-1。`sales_mgmt_slip_number` は別物）
6. 施工担当者の概念無し（08 DM-7）
7. アフター掲示板の「次回対応者→送付先」ルーティングは `InquiryRecipientRoute` が status_code ベースのみで、対応者ベース経路は未実装（05 §5-2）

## R7 に持ち越す未決事項一覧（04 R7 反映用）

| ID | 内容 | 出典 |
|---|---|---|
| Q-移7 | `agencies` に住所・電話カラムが無い。旧CSVの代理店住所・電話の載せ先／管理要否 | 08 §1・§2 |
| Q-移15 | 月額料金のスナップショット（受注時 `monthly_fee`）保存の要否。無いと旧プラン価格変更で既存契約の表示額が変わる | 07 §1-2 |
| Q-移18 | 契約単位(168)/初期構築(169) フィールドの対応先未定 | 07 §3 / 11 |
| DM-7 | 施工担当者36件の扱い（新スキーマに概念なし。R1 組織領域の要否確認） | 08 §1・§3 |
| DM-6 | 旧→新ステータスマッピングと `0:受注` 既定値の整合（上記矛盾1） | 03 §3 / 08 §3 |
| DM-8 | 旧 FTW 顧客番号の保持列が無い（`orders.serial_id`/`bridge_migration_order_number` は案件側のみ）。`customer_number` に旧番号を入れるか新採番か、`sequence_counters` 開始値 | 08 §3 |
| DM-1/Q-C | 掲示板42万件の `Inquiry` 投入範囲（参照アーカイブは決定済み。投稿者名寄せは `name-matching-process.md`） | 08 §1 |
| DM-5 | Bridge/BridgePlus の断面確定（営業担当 109 vs 310 等の件数差） | 08 §1 |
| 初期データ | `OptionGroup` 選択肢（属性1〜11 等）、掲示板転送先13件→`RecipientGroup`/`InquiryRecipientRoute`、旧プラン40種超（`is_active: false`）、旧ステータス（`order_statuses` 追加分）の投入 | 05 §4・§5 / 07 §1 / 03 §3 |
| 会員ID | 旧CRMエクスポート「ネットムーブ会員ID」列 → `customers.netmove_member_id` の取り込み ETL（R5 の採番連続性と連携） | 02 §4-7・§7-b |

## 04-rails-implementation-plan.md へ反映すべき新規タスク／変更

| フェーズ | 優先度 | 内容 | 出典 |
|---|---|---|---|
| R5（着手前） | 高 | **案件初期ステータスの決定**: `orders.status` 既定値 `0:受注` を維持するか、精査どおり「受注」を廃し別コードを初期状態にするか。R5 状態機械設計・R6 遷移バリデーション・R7 DM-6 に波及 | 03 §3 / 08 DM-6 |
| R5 | 中 | 顧客本人が契約情報を入力する導線（方針⑥）の要否・実装（R3 は営業担当者ログイン前提） | 01 §2-1 #4 / 04 §2 |
| R5 | 中 | 伝票番号（発送用/返送用）カラムの要否（ファクター＝口振用紙の発送・返送管理） | 05 §2-1 |
| R6 | 中 | 案件検索へメールアドレス条件（P4-6）。現行 `Admin::OrdersController` は order_number/status のみ | 04 §1-1 #14 |
| R6 | 中 | 店舗メール／管理者メール（「;」区切り複数）の受け皿要否 | 05 §2-1 |
| R6 | 低 | アフター問合せの「次回対応者→送付先」ルーティング（対応者ベース経路）の要否 | 05 §5-2 |
| R7 | 高 | R7 既知の未決事項に **DM-6（`0:受注`）・DM-8（旧番号保持・採番開始値）** を追加（現行は Q-移7/15/18・DM-7 のみ記載） | 03 §3 / 08 §3 |
| R7 | 中 | 初期データ投入タスクの明記: OptionGroup 選択肢シーダー（旧 P2-5）、掲示板転送先13件→RecipientGroup/InquiryRecipientRoute、旧プラン一括投入（is_active:false）、`prefecture_id`→文字列変換表 | 05 §4・§5 / 07 §1 / 08 §2 |
| R7 | 中 | 移行ツールの実装方式を明記（rake タスク／`rails runner`、UUID 主キーのため旧数値ID対応表を保持） | 08 §4 |
| R8 | 低 | 添付ストレージ本番先（S3 等）と上限（現行 Active Storage 50MB/ファイル・合計制限なし）の確定 | 05 §3 |
| 記録 | 低 | 04 R7 の「legacy-research/全16ファイル」表記は 00〜15 の16ファイル（本改訂で 00 §1 に 15 を追加済み）で整合 | 00 §1 |

## 決定者/業務側の確認が必要な未決論点

1. 案件の初期ステータス「受注(0)」を新システムでも使うか（精査は削除、実装は既定値）— 03 §3
2. Q-移7: 代理店の住所・電話を新システムで管理するか — 08
3. Q-移15: 月額料金を受注時にスナップショット保存するか（旧プラン価格変更の影響） — 07
4. Q-移18: 契約単位/初期構築フィールドの対応先 — 07/11
5. DM-7: 施工担当者36件を新システムで扱うか — 08
6. DM-8: 旧 FTW 顧客番号を `customer_number` として引き継ぐか新採番か — 08
7. 顧客本人による契約情報入力（方針⑥）を R5 で実装するか — 01
8. FAQ 返信テンプレート（318件・12カテゴリ）の要否・フェーズ — 04 §1-1（04 R4 既出）
9. 未収情報フィールド（売上年月・請求先名・未回収額・合計）・予備欄の要否 — 04 §3（04 R2 既出）
10. Q-背1〜4（月次レポート／プラン集約時期／契約期間・違約金／音声ログ）— 01 §5（既出・未決のまま）

---

<!-- ===== summary-I-legacy-2 ===== -->

## サマリ I-legacy-2: legacy-research 09〜15 ＋ name-matching-process.md（Rails版改訂 2026-08-19）

対象: `requirements/design/legacy-research/09-data-cleansing.md` / `10-migration-mapping.md` / `11-order-field-mapping.md` / `12-schema-gap.md` / `13-faq-templates.md` / `14-remaining-materials.md` / `15-test-purchase-20260728.md` / `requirements/design/name-matching-process.md`（8ファイル、全て同一パスで上書き。git 操作なし・他ファイル未編集）。
突合の正: `db/schema.rb`（Python でテーブル→カラム集合を解析）、`app/models/*`、`app/controllers/admin/{inquiry_messages,notifications,notification_templates}_controller.rb`、03/04、review-05。

## 1. ファイルごとの主な改訂内容

### 09-data-cleansing.md（R7・ETL 整形ルール）
- 改訂ヘッダ追加。整形ルール C-1〜C-7・件数・破損の調査事実は不変。
- §6-2 実装手段を Rails 版に全面書き換え: Artisan `migrate:legacy` → rake `legacy:migrate` / `rails runner`、LazyCollection → `CSV.foreach`＋`each_slice(500)`＋`insert_all/upsert_all`、`heavy-processing` → Solid Queue 専用キュー、`--dry-run` → `DRY_RUN` 環境変数 or Rollback 方式。
- Rails 固有の追加論点: 暗号化列（`order_work_details` アカウント8列・`orders.billing_password`）は `encrypts` を通すためモデル経由投入必須／`Auditable` による大量監査ログの抑止要否／`SequenceCounter` の繰り上げ／`bbs_id` の受け皿（`legacy_migration_logs`）。
- 移行先を `stores`・`inquiries`/`inquiry_messages`（R4 実装済み）へ読み替え。Q-移1（参照アーカイブ決定済み）/Q-移2（name-matching-process.md へ）の決着先を追記。

### 10-migration-mapping.md（R7・グループ/代理店/営業/店舗/掲示板の対応表）
- `organizations.id` → `agency_groups.id` / `agencies.id`（Rails 版に organizations テーブル無し）、`jasmin_stores` → `stores`、`jasmin_customer_id` → `customer_id`、`updateOrCreate` → `find_or_initialize_by`/`upsert_all`。
- §2〜§6 の全表に「実装状況」列を追加（R1/R2/R4 実装済み・NOT NULL 制約・UNIQUE を明記）。
- §6 掲示板の移行先を「Q-C 確定後に定義」から R4 実装済み `inquiries`/`inquiry_messages` に更新し、34列→新カラムの対応（category 4値・`inquiry_statuses`・after_* 列・`created_by_id`・`first/next_responder_name`）を列挙。
- 新規論点: `agency_groups.service_type`（NOT NULL）と現行「区分」列の対応可能性（Q-移11 補足）、Q-移19（営業担当者 `email`＝受注入力 OTP 送信先の補完元）、Q-移20（`orders.contract_condition_id` NOT NULL の受け皿＝移行用既定契約条件）。

### 11-order-field-mapping.md（R7・案件238フィールド）
- テーブル名を実装名へ更新、`name_kana` → 実装名 `contractor_name_kana`。§1〜§4 の各表に「実装状況」列を追加。
- **全238フィールドを `db/schema.rb` と機械突合し付録Aとして全行掲載**（受注フィールド一覧xlsx のヘッダ238列 × 本書の対応 × schema.rb カラム集合。値は未読）。
- 突合結果: 実装済みカラム対応 **219**（orders 84 / order_work_details 75 / customers 42 / stores 17 / plans 1）＋ FK 参照解決 **9**／**未実装 2**（168 契約単位・169 初期構築 → Column.md `plans.contract_unit`/`initial_construction` は設計済みだが schema 未反映）／**対応先なし 8**（13/14 アポインター2人目・79 店舗メール・120 担当者生年月日・132-134 用途不明・233 ID）。
- §5/§6 更新: Q-移12/14/16 解決、Q-移13 は2人目のみ残存、Q-移15/17/18 残存。旧「P2-4 で実装すれば解決」は「R2 実装済み」に。

### 12-schema-gap.md（歴史的記録・解消済み）
- 改訂ヘッダで「歴史的記録」と明示。§0 表に Rails 版 schema.rb の実カラム数（customers 65 等）と「解消状況」列を追加。
- §1 の 38 カラムは全て `customers` に存在（`phone_number` のみ実装名 `phone`）→ 各節に「✅ 解消済み（R2）」。
- 残存ギャップとして `plans.contract_unit`/`initial_construction`（Q-移18）とアポインター2人目を明記。`payment_transactions` は R5 未着手と注記。

### 13-faq-templates.md（FAQ 318件・R4後続/R6/R7 未決）
- R4 実装（`NotificationTemplate` 4列・template_type 3値・管理CRUD・一斉通知でのテンプレ選択→コピー）と突合し、F-1〜F-5 に実装状況列を追加。
- 未実装を明記: FAQ 12カテゴリマスタ（`inquiries.category` は掲示板4種で別軸）／差し込み変数展開／問い合わせ返信画面（`Admin::InquiryMessagesController#create` は body・添付のみ）でのテンプレ選択 UI／318件の初期データ投入。一斉通知側の選択→コピー機構が流用可能と注記。実装フェーズは 04 で未決（決定者確認事項）と注記。
- 削除済み `Inquiry-email.md` 参照を注記付きで差し替え。

### 14-remaining-materials.md / 15-test-purchase-20260728.md
- 改訂ヘッダ＋各「新システムでの対応」に R フェーズと実装状況（R4 実装済み／R5・R6 未実装）を付記。調査内容は不変。
- 15: 削除済み `impl-plans/P3-2-payment.md`・`_NEXT.md` 参照を 04 R5 へ差し替え。テスト購入結果が本ファイルに未記入のままである点を注記。

### name-matching-process.md（R7・未実装）
- Artisan → rake（`lib/tasks/legacy.rake`: `legacy:extract_posters`/`legacy:match_posters`）/`rails runner`/Solid Queue ジョブ、Eloquent → ActiveRecord、MySQL → PostgreSQL 16、`storage/app/private/etl/` → `storage/private/etl/`（pii-handling-rules.md Rails 版と一致）、`jasmin_customers` → `customers`。
- 部分一致段階に pg_trgm / pg_bigm 類似検索を候補追加（pg_bigm は `db/Dockerfile` 同梱・`enable_extension` 未実行、schema.rb は plpgsql のみ）。
- 紐づけ先4テーブルの実装状況と、書き込み先（R4 実装済み）の実態を追記: 投稿者は `inquiry_messages.created_by_id`（users FK・NULL 可）＝staff のみ FK 表現可、対応者は `first/next_responder_name`（文字列）、`legacy_poster_name` 未実装、sales_rep/customer/agency 投稿者の FK 列なし。
- §5 c 案に「実装は既に NULL 許容だが推奨 a は維持」を注記。ダミー「移行ユーザ」と `legacy_poster_name` 追加を R7 要求事項として明記。

## 2. 現行実装との差分・未実装事項（フェーズ付き）
| 事項 | 状況 | フェーズ |
|---|---|---|
| ETL 本体（rake/Solid Queue）・`legacy_migration_logs`・ドライラン・検証 V-1〜V-7 | 未実装 | R7 |
| 名寄せ手順（抽出/機械マッチング/人手確認リスト）・ダミーユーザ・`legacy_poster_name` 列 | 未実装 | R7 |
| `plans.contract_unit` / `initial_construction`（Column.md 設計済み・schema 未反映。案件238の168/169） | 未実装 | R2追補 or R7（要否判断） |
| 案件238の対応先なし 8件（13/14/79/120/132-134/233） | 列なし | R7（要否判断） |
| `inquiries`/`inquiry_messages` に旧ID列・投稿者 polymorphic 列なし | 設計差分 | R7 |
| NOT NULL 制約に起因する受け皿: `stores.customer_id` / `sales_representatives.agency_id` / `orders.contract_condition_id` / `inquiries.order_id` | 設計差分（Laravel 時代の対応表は NULL 前提で書かれていた） | R7 |
| `customers.email` UNIQUE（重複メール顧客の投入不可） | 設計差分 | R7 |
| `sales_representatives.email`（受注入力 OTP）が旧 CSV に無い | 運用要確認 | R7 |
| FAQ テンプレ: カテゴリマスタ／差し込み変数／返信画面テンプレ選択 UI／318件投入 | 未実装 | R4後続/R6/R7（未決） |
| `payment_transactions`（14 のクレカNG自動追跡の前提） | 未実装 | R5 |
| pg_bigm/pg_trgm の `enable_extension` | 未実行 | R7（名寄せ用途なら一時DBで完結も可）／R8 全文検索 |

## 3. 04-rails-implementation-plan.md へ反映すべき事項

### 3-1. R7 節に追記（優先度: 高）
- **案件238フィールドの突合結果**（出典: `legacy-research/11` §0・付録A）: 実装済み 219 ＋ FK 9／未実装 2（`plans.contract_unit`/`initial_construction`＝Q-移18）／対応先なし 8（アポインター2人目 13/14・店舗メール 79・担当者生年月日 120・用途不明 132-134/233）。**移行先未実装は計10件、いずれも新規機能（R5/R6）依存なし。R7 着手前に要否判断**。
- Q-移18 の記述を更新: 「対応先が未定」→「Column.md は `plans` 側に設計済み・schema 未反映。案件スナップショット（orders 側）かプラン属性（plans 側）かを含め要否判断」。
- 新規論点 Q-移19（営業担当者 `email` の補完元・初回ログイン運用）、Q-移20（`orders.contract_condition_id` NOT NULL の移行用既定契約条件）を既知事項リストに追加（出典: `10` §4/§8）。
- 12-schema-gap.md の記述はそのまま（「解消済み・歴史的記録」で正しい）。

### 3-2. R7 タスク分解案（04 R7 節の箇条書き化用）
1. **R7-1 移行基盤**: `lib/tasks/legacy.rake`（`legacy:migrate[entity]`・`DRY_RUN`）、`legacy_migration_logs` テーブル（旧ID↔新UUID・警告）、Solid Queue 専用キュー、`requirements/input/` の作成、監査ログ抑止方針の決定（出典: `09` §6）。
2. **R7-2 マスタ移行**: agency_groups（`service_type` の既定/対応）→ agencies（Q-移7 住所電話要否）→ sales_representatives（`agency_id` 復元 Q-移8・`email` 補完 Q-移19・`sales_rep_code` 重複解消）→ 移行用既定 contract_conditions（Q-移20）（出典: `10` §2〜4）。
3. **R7-3 顧客・店舗・案件移行**: 案件CSV（CP932）を起点に customers → stores（`customer_id` 復元 Q-移9）→ orders/order_work_details（暗号化列はモデル経由）。住所分割 Q-移10/17、ステータスコード変換表（C-6）、`SequenceCounter` 繰り上げ、`customers.email` 重複方針、未実装10件の要否判断（出典: `11` 付録A・`09` C-2/C-4/C-6）。
4. **R7-4 掲示板42万件→Inquiry 参照アーカイブ**: `inquiries.category/status`（`inquiry_statuses` 変換表）・スレッド復元・`order_id` 未解決分の受け皿・`legacy_poster_name` 列追加・本番テーブルか別アーカイブかの実装方式（出典: `10` §6・`09` C-3）。
5. **R7-5 名寄せ表（律速・先行着手）**: `legacy:extract_posters`/`match_posters`、pg_trgm/pg_bigm 候補、ダミー「移行ユーザ」、業務側レビュー窓口と SLA、精度目標 97%（出典: `name-matching-process.md`）。第1周を B-7 初回の約1か月前に開始。
6. **R7-6 検証・リハーサル**: V-1〜V-7、冪等再実行、`release-readiness.md` B-7（出典: `09` §7）。
7. **R7-7 データ投入（非移行）**: FAQ 318件のテンプレ投入は要否確定後（3-3 参照）。

### 3-3. R4「未実装ギャップ」の補強（優先度: 中。出典: `13` §3）
- FAQ テンプレ機能の未実装4点を列挙: (1) カテゴリ/タグ列、(2) 差し込み変数展開、(3) 返信画面テンプレ選択 UI（一斉通知側 `Admin::NotificationsController` の選択→コピー機構を流用可）、(4) 318件の seed/rake 投入。実装要否とフェーズ（R4後続/R6/R7）は 決定者 確認事項のまま。

### 3-4. R2 追補候補（優先度: 中）
- `plans.contract_unit`/`initial_construction`（＋Column.md §4 にある `initial_fee`/`payment_method`/`plus_flag`）が schema 未反映。Column.md と schema.rb の差分として R2 追補にするか R7 まで保留するかを決める（出典: `12` §0/§2-3、`11` §5）。

### 3-5. R5 関連（優先度: 低・既存記述の裏付け）
- `14` §3 クレカNG自動追跡は `payment_transactions`（R5）前提、通知先は E6 未決（既に R5 着手前チェックリストにあり）。`15` のテスト購入結果は未記入＝Q-37/38 の一次確認が未了である点を R5 着手前チェックリストの注記に追加してもよい。

## 4. 決定者/業務側の確認が必要な未決論点
1. 案件238のうち移行先が無い10件の要否: 契約単位/初期構築（168/169）の置き場所、アポインター2人目、店舗メール、担当者生年月日、用途不明列（132-134/233）。
2. Q-移7: 代理店の住所・電話を移行するか（`agencies` にカラム追加要）。
3. Q-移15: 月額料金の契約時スナップショット要否（R5 請求と関連）。
4. Q-移19: 営業担当者のメールアドレス（受注入力 OTP 必須）の補完元／未設定者の運用。
5. Q-移20: 旧案件に紐づける契約条件（`contract_conditions`）の扱い（移行用既定条件を代理店ごとに生成するか）。
6. 掲示板42万件の参照アーカイブ実装方式（本番 `inquiries` に投入 vs 別テーブル）、案件に紐づかない投稿・`first_insert_*`・`make_type` の保持要否。
7. 名寄せ: 精度目標案B（97%）・残余方針a（単一ダミーユーザ＋原文保持）の承認、業務側レビュー窓口・SLA、`FT` 等の略号の意味。
8. FAQ テンプレ機能（13）の実装要否とフェーズ（既に 04「次のアクション」5 に記載。今回は未実装内容を具体化しただけ）。
9. 移行投入時の監査ログ（`audit_logs`）を残すか抑止するか。

---
