# 開発計画書（全体像・未決定事項台帳・変更履歴）

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/development-plan.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。フェーズ対応: **R0〜R8 全体**（フェーズ詳細の正は `design/04-implementation-plan.md`）。突合対象: `db/schema.rb` / `app/**` / `config/**` / `spec/**` / `.github/workflows/ci.yml` / git log（R0〜R4 コミット）。

> 最終更新: 2026-08-19
> ステータス: brige-crm（Rails 8.1 再構築）側の全体計画へ作り直し。R0〜R4 実装済み・R5 着手前
> 位置づけ: **本書は brige-crm 側の全体開発計画の「入口」**。役割は (1) 全体像・システム概要、(2) 旧Laravel フェーズ P0〜P5 と Rails フェーズ R0〜R8 の対応表、(3) 未決定事項 Q-xx の台帳、(4) 変更履歴 の4つ。**フェーズごとのタスク詳細・完了条件・着手前チェックリストは `design/04-implementation-plan.md` が正**であり、本書には転記しない。

---

## 0. ドキュメント体系と役割分担

| ファイル | 役割 | 更新タイミング |
|---|---|---|
| **`development-plan.md`（本書）** | **全体像・P→R 対応表・未決定事項台帳（§8）・変更履歴（§9）** | フェーズ着手/完了時・Q の起票/決定時 |
| `design/01-laravel-current-analysis.md` | 旧 Laravel 実装の現状分析（移植元の棚卸し・負債 T-1〜T-5） | 参照のみ（凍結） |
| `design/02-ftlog-architecture-analysis.md` | ftlog（Rails）解剖。認可 RBAC・OTP・監査の移植元 | 参照のみ |
| `design/03-rails-architecture-proposal.md` | **技術スタック・設計方針の正**（決定A〜F §8、CTO自律決定 §8-2） | 構成決定時 |
| `design/04-implementation-plan.md` | **フェーズ R0〜R8 の実装計画の正**（各 R のタスク・完了条件・見直し残タスク・R5着手前チェックリスト・次のアクション） | フェーズ着手/完了時 |
| `design/review/review-01〜05-*.md` | 01〜04 の突合レビュー、旧設計ドキュメント一括精査（review-05） | レビュー実施時 |
| `design/basic-design.md` | 機能仕様の正（18章・項番管理。Rails 版へ改訂中） | 要件追加・確定時 |
| `design/Column.md` | スキーマ（カラム）設計の正。実装後は `db/schema.rb` と併読 | テーブル追加・変更時 |
| `design/form-template-mapping.md` | 申込フォームのフィールドマッピング設計（R3 実装済み。155項目突合は未） | フォーム項目変更時 |
| `design/business-flow-analysis.md` | 実業務フロー分析（現行運用の実態・差分 G-1〜G-9・Q-A〜Q-H） | 業務ヒアリング時 |
| `design/payment-integration.md` | 決済連携設計（ネットムーブ。R5 最大の作業） | 情報受領時・決定時 |
| `design/contract-confirmation-docs.md` | 重要事項説明チェック・申込確認メール/確認書（R5） | R5 設計時 |
| `design/netmove-card-migration.md` | ネットムーブ会員ID・カード引継ぎ（R5/R7） | 同上 |
| `design/customer-merge-design.md` | 顧客統合（名寄せ）設計（R6） | R6 設計時 |
| `design/export-profile-design.md` | CSV 出力プロファイル汎用化（R6・P4-12） | 同上 |
| `design/board-implementation-options.md` | 掲示板4種→問い合わせ統合の決定根拠（R4 実装済み・R7 アーカイブ） | 参照のみ |
| `design/status-naming-analysis.md` | ステータス呼称（Q-B）分析。実装は `order_statuses` 側のみ適用済み | Q-B 完了時 |
| `design/notification-matrix.md` | 通知受信者マトリクス（Q-21。R4 実装先行・未決セルあり） | 業務確認時 |
| `design/pii-handling-rules.md` | PII 取扱ルール（Q-A/Q-D） | ルール確定時 |
| `design/name-matching-process.md` | 掲示板投稿者名寄せ手順（R7） | R7 設計時 |
| `design/release-readiness.md` | **本番リリース準備チェックリスト**（非機能・運用・法務。R8 の Go/No-Go 判定軸。基盤スタックの正は 03§2） | リリース準備時 |
| `design/legacy-research/` | 現行資料の徹底調査ノート（00〜14。R7 の一次資料） | 資料調査時 |

**削除済み（旧Laravel側 `boilerplate-vue-env/laravel/requirements/` に残存・brige-crm へは持ち込まない）**: `Inquiry-email.md`（R4 実装で上書き）、`ftlog-port.md`（Rails 版は ftlog 本体を直接一次情報とする）、`basic-cost.md`（MySQL/ElastiCache/Horizon 前提で 03 決定と矛盾。R8 で再試算）、`branch-merge-policy.md`、`test-code-plan.md`、`test-file-review.md`、`remaining-tasks.md`（7-1 未収情報のみ 04 R2 追加タスクへ拾い上げ済み）、`impl-plans/`（Laravel 実装計画。Rails 版は 04 が担う）。精査結果は `design/review/review-05-legacy-design-docs-sweep.md`。

**参照の向き**：本書 → 04 → 各設計書（一方向）。仕様の詳細を本書に転記しない（二重管理を避ける）。

### 更新ルール

1. 新しい開発内容は、まず **`04-implementation-plan.md` の該当 R フェーズ**に 1 行追加する（本書には書かない）。
2. 仕様が固まったら `design/` に設計書を作り、04 からリンクする。
3. 未確定の論点は本書 §8「未決定事項」に積む（Q 番号は通し・欠番再利用禁止）。決まったら「状態」列を更新し、04 の該当 R フェーズへ移し、履歴を §9 に残す。
4. 旧Laravel の P 番号（P3-4 等）で参照されている箇所は、§3 の対応表で R フェーズへ読み替える。

---

## 1. システム概要

| 項目 | 内容 |
|---|---|
| システム名 | **未定**（新サービス名称は未決。リポジトリ名 `brige-crm` を仮称として使う。内部モデル名は汎用名 = 決定D） |
| 目的 | 既存 Bridge / BridgePlus の受注・契約管理を新システムへ刷新（現行ベンダー：リクリック 77,000円/月） |
| リポジトリ | `projects/brige-crm`（Rails 8.1 再構築。旧 `jasmin_laravel` / `boilerplate-vue-env` は凍結参照元） |
| 技術構成（03§2） | Ruby 3.3.4（`.ruby-version`。03 記載は 3.4 → release A-14 で要整合）/ Rails 8.1 / Hotwire（Turbo + Stimulus）+ ERB / importmap-rails + propshaft（Node レス）/ Tailwind CSS v4（tailwindcss-rails）/ PostgreSQL 16（+pg_bigm、UUID 主キー）/ Solid Queue・Solid Cache・Solid Cable（Redis レス）/ Puma + Thruster / Docker（db・web・tailwind・worker・mailpit）/ Kamal 雛形（採否未定） |
| 主要 gem | devise / pundit / rack-attack / pagy 8 / csv / solid_* / kamal / thruster / rspec-rails / factory_bot_rails / shoulda-matchers / rubocop-rails-omakase / brakeman / bundler-audit / annotaterb |
| 認証系統（03§4） | ①管理画面（Devise `User`：社内/代理店G/代理店。メール+PW＋メールOTP）②受注入力画面（`Form::SessionsController` 独自セッション：代理店CD＋営業担当者CD＋メールOTP。`SalesRepresentative` は Devise 対象外）③顧客マイページ（Devise `Customer` 別スコープ＋メールOTP）。IP許可リスト（`IpAllowlistEntry`）で OTP 免除・空リスト=全員必須 |
| 認可（03§3） | レイヤー1: ftlog 式エンドポイント RBAC（`SystemPermission`/`SystemRole`/`SystemRolePermission`/`UserSystemRole` + `SystemPermissionChecker` + `SystemPermissionSyncService` + `RoleSeeder`、section = admin/form/mypage、フェイルクローズ）。レイヤー2: Pundit `policy_scope`（代理店=自代理店のみ・グループ=配下のみ） |
| 監査 | `Auditable` / `AuthAuditable` concern → `AuditLog`（TRACKED_FIELDS・request_id・IP・差分。保存5年）。ログイン履歴は AuditLog の絞り込みビュー |
| 参照システム | **ftlog**（Rails）：RBAC・メールOTP・監査ログ・通知・マニュアルの実装を**直接移植**（§7） |
| 決済 | **ネットムーブ**（3Dセキュア対応EC決済API・リダイレクト型。`legacy-research/02` / `payment-integration.md`）。R5 未着手 |

---

## 2. 現状サマリ（2026-08-19 時点）

### 実装済み（R0〜R4。詳細・見直し残タスクは 04 各節）

| R | 領域 | 内容（`app/` の実態） |
|---|---|---|
| R0 | 基盤 | rails new（Rails 8.1.3.1）・Docker 5 サービス・CI 5 ジョブ（rubocop / brakeman+bundler-audit / importmap audit / rspec on PostgreSQL 16+pg_bigm / authorization_guard）・Devise User + メールOTP（`OtpAuthenticatable`）・rack-attack・IP許可リスト・ログイン履歴・RBAC 4 モデル＋Checker/SyncService/RoleSeeder＋権限マトリクス UI・ロール管理 UI・Pundit 基盤・`Auditable`/`TracksUser`/`Current`・RSpec+FactoryBot+認可ハーネス・起動時 `permissions:sync` |
| R1 | 組織・アカウント | AgencyGroup / Agency / SalesRepresentative（`sales_rep_code` グローバルユニーク = T-2 是正）/ ContractCondition / User CRUD、`AgencyScoped` Pundit スコープ、ユーザ CSV 一括アップロード（`UserCsvImportJob`）、`is_active` 無効化 |
| R2 | CRM 中核 | Customer（37 拡張カラム込み・`netmove_member_id`）/ Store / Order（`contract_condition_id` は orders 側 = T-3 是正）/ OrderWorkDetail（SNS 認証情報 8 カラム `ActiveRecord::Encryption`）/ OrderOption、Product / Plan / ProductInitialFee / ProductOption / AgencyProduct / AgencyGroupProduct（販売許可・UI 未）、OptionGroup / OptionValue（parent_id ツリー）/ CustomerStatus / OrderStatus（`StatusSeeder`）/ ProductionCompany / SalesMaterial、`SequenceCounter` 採番、pagy、CSV 非同期エクスポート（`CsvExport` + `CsvExportJob`：Customer/Order） |
| R3 | 申込フォーム | `Form::BaseController` + `Form::SessionsController`（代理店CD＋営業担当者CD）+ `Form::OtpsController`、FormTemplate / FormStep / FormField（target_table / target_column ホワイトリスト / editable_by_tier / lock_after_status）、動的マルチステップ + `Form::DynamicFormValidator`、`Form::ApplicationSubmissionService`（Customer+Store+Order+Application 一括生成）、フォームビルダー UI（`Admin::FormTemplatesController`） |
| R4 | 問い合わせ・通知 | Inquiry / InquiryMessage（添付）/ InquiryStatus（種別別マスタ）/ InquiryRecipientRoute / InquiryMessageRecipient、`RecipientResolver` / `InquiryNotifier` / `InquiryMessageMailJob`、Notification / NotificationRecipient / NotificationTemplate / RecipientGroup（`NotificationDeliveryJob`・スケジュール送信）、SystemNotification（Solid Cable リアルタイム・30日 prune を Solid Queue recurring で）、顧客マイページ（Devise Customer + OTP + ダッシュボード最小） |

主要テーブル 48（`db/schema.rb`）。RSpec 38 ファイル（request 19 / model 12 / job 4 / service 3）。

### 未実装（設計書に記載あり・コード無し）

| # | 機能 | R フェーズ / 参照 |
|---|---|---|
| A | クレカ決済の外部連携（ネットムーブ）・PaymentTransaction 状態機械 | **R5**（`payment-integration.md`） |
| B | 手書き署名の取得・保存 | R5（basic-design §6） |
| C | 契約書 PDF 生成・参照 | R5（basic-design §13,14。PDF ライブラリ選定含む） |
| D | 不備チェック→差戻し→確認コール→契約確定 のワークフロー | R5（basic-design §9〜12） |
| E | 入力チェック設定（3段階必須） | R5（basic-design §8。R3 の DynamicFormValidator は固定バリデーションのみ） |
| F | キーワード自動選定 | R5（basic-design §11） |
| G〜J | 項目一括更新／顧客名寄せ／統合ビュー／顧客退会 | R6（退会 P4-29 は 04 未反映 → §3-2） |
| K〜L | 画面別データ出力プロファイル／顧客統合 | R6（P4-12 / P4-4） |
| M | メンション／通知一覧強化／監査ログ検索・CSV 画面 | R6 |
| 運用 | 遅延案件／自動キャンセル／集計／連携状況／CSV取込／GBP管理／音声ログ／ガルーン連携／KW管理／レクチャー管理 | R6（一部 04 未反映 → §3-2） |
| 非機能 | デプロイ／監視／バックアップ／法務／マニュアル／UAT／性能 | R8（`release-readiness.md`） |
| 移行 | ETL・掲示板アーカイブ・名寄せ | R7 |

### 技術的負債・懸念（旧 T-1〜T-6 の Rails 版での状態）

| # | 内容 | 状態 |
|---|---|---|
| T-1 | テストが管理画面 CRUD に偏る | ✅ R0〜R4 範囲では解消（request spec 中心・認可/参照制御/OTP/申込トランザクション/採番並行性をカバー）。R5 の決済状態機械・契約状態機械 spec は 04 R5 で必須化済み。E2E・UAT は R8 |
| T-2 | `sales_rep_code` が複合ユニーク | ✅ R1 でグローバルユニークに是正 |
| T-3 | `contract_condition_id` が顧客側 | ✅ R2 で orders 側に是正 |
| T-4 | `Customer` モデルの役割の曖昧さ（契約主体とログイン主体の兼務） | 🔶 03§8-2 CTO 決定: 決定D の通り `Customer` で進める。R2 完了後に CEO へ再分割要否を提案する形で持ち越し（未提案） |
| T-5 | `composer.json` の name（Laravel 固有） | — 該当なし |
| T-6 | `organizations` 前提の旧記述 | ✅ 03§5: nestedset/organizations は持ち込まない。実装は AgencyGroup/Agency + `users.agency_group_id/agency_id`。`basic-design.md` §3 の旧記述は同書の Rails 版改訂で追従 |
| T-7（新） | Ruby バージョン差異（03 記載 3.4 vs 実態 3.3.4） | R8 で整合（release A-14） |
| T-8（新） | Q-B（ステータス呼称）が `order_statuses` 側のみ適用・`customer_statuses` は「顧客ステータス」のまま | 04 R2 追加タスク・CEO 確認事項 |
| T-9（新） | セッション/Cookie ハードニング未実施（`force_ssl`・`expire_after`・form ログイン時 `reset_session`・`config.hosts`） | 04 R3 見送り事項 → release C-13（本番前必須） |
| T-10（新） | rack-attack のスロットルが `/users/*` のみで form/mypage の OTP・ログインに未適用 | release C-6 → R5 前の小改修 or R8 |
| T-11（新） | `verify_authorized`/`verify_policy_scope` 未導入（Pundit 呼び出し漏れの機械検出無し） | 04 R0 見送り事項 → release F-10（R5 前推奨） |

### 外部・他部門待ち

| # | 待ち事項 | 状態 |
|---|---|---|
| ~~W-1~~ | 決済API仕様 | ✅ 解消（`legacy-research/02`）。残は接続情報・HMACキー |
| ~~W-2~~ | 顧客詳細フィールド定義 | ✅ 実質解消（155項目＋現行仕様書＋受注238カラム。R2 実装済み） |
| ~~W-3~~ | Bridge側の代理店・営業担当者データ | ✅ 実質解消（DB退避データに全件） |
| W-4 | 情シスへのリスク連携／法務の決済フロー確認 | R8（release G-1/G-2）。本番構成（Q-40）、DNS/メール送信、DB/ストレージ、監視/バックアップ、個人情報保管場所 |
| W-5 | **カットオーバー当日のリクリック作業合意**（旧環境停止・最終データ退避・リハーサル同席・切り戻し依頼ルート・時間外対応可否・費用） | **未依頼**。下記 N-1。リリース日程の前提 |
| M-2残 | ネットムーブ開通処理・HMACキー・商用カード検証方法確認 | R5/R8（release D-1）。検証専用環境が無い可能性が高い |

### DB 方針（旧「MySQL 8.4 LTS 決定」の置換）

**旧Laravel側の決定（2026-07-27・全環境 MySQL 8.4 LTS）は Laravel 側限定の旧決定であり廃止。03 決定A（2026-08-14・CEO決定）により PostgreSQL が正。**

| 環境 | Rails 版の状態 |
|---|---|
| ローカル開発 | ✅ `docker-compose.yml` db サービス = `db/Dockerfile`（`postgres:16` + pg_bigm 1.2-20240606） |
| CI | ✅ 同イメージをビルドして起動・`db:schema:load` → rspec（migrate/rollback smoke は未 → release F-9） |
| 本番／ステージング | 未構築（R8）。PostgreSQL 16 系・pg_bigm 利用可能なホスティング（RDS/Aurora では標準サポート拡張）。primary/cache/queue/cable の 4 DB 構成（`config/database.yml`） |

- 旧決定の副次効果として挙げていた「MySQL 8.0.29 以降の instant DDL」は PostgreSQL では論点にならない（`ADD COLUMN` は元より軽量）。
- UUID 主キー（`gen_random_uuid()`）・全文検索（pg_bigm）・ftlog パターン流用が採用理由（03§2）。

### ⚠️ 注意事項（カットオーバー／データ移行）

#### N-1. 移行データは「事前に受け取って整形しておく」方式では成立しない（他社=リクリック経由の当日作業が必須）

**登録日: 2026-07-27（仕様指摘）。Rails 版でも前提は不変（R7/R8 に引き継ぐ）。**

- **問題**：「リクリックから現状データを退避してもらう → こちらで整形しておく → 新環境リリース時に投入」は、
  **切り替え時点のデータにならない**ため成立しない。事前に受け取った退避データは、その後の旧環境での受注・入金・問い合わせ更新分を含まず、
  そのまま投入すると**切り替え直前の営業日分のデータが欠落**する。
- **本来必要な手順（カットオーバー当日の直列作業）**：

  ```
  ① 旧環境（Bridge/BridgePlus）を停止（更新を止める）
      ↓  ※リクリック作業
  ② リクリックが最終データを退避（エクスポート）
      ↓  ※受け渡し
  ③ こちらでデータを加工・整形（ETL = rake タスク：分割列結合・掲示板横→縦・名寄せ・文字コード CP932 変換 等）
      ↓
  ④ 新環境へインポート（load）＋検証
      ↓
  ⑤ 新環境を公開（切り替え完了）
  ```

  **①②が自社で完結せず、他社（リクリック）を経由しなければ実行できない**点が本件の本質的なリスク。

- **リスク**：
  1. **ダウンタイムが他社の作業時間に依存する**。②の所要時間・着手可能時刻をリクリックが握るため、停止時間を自社で確定できない。
  2. **カットオーバー日時が他社の稼働日時に律速される**（夜間・休日・時間外対応の可否が未確認）。
  3. **③のETL所要時間が未実測**。全件（掲示板42万件含む）の実データで測っていないため、停止時間の見積り自体が立っていない。
  4. **切り戻し（ロールバック）も他社依存**。失敗時に旧環境を再稼働させるにもリクリックへの依頼が必要で、判断から復旧までのリードタイムが読めない。
  5. **退避データの形式・破損が当日判明するリスク**（CSV破損・文字コードは `legacy-research/09` で既知）。当日初めて本番形式を受け取る運用は不可。

- **必要な対応（R7／R8 で計画に落とす。旧 P5-5／P5-11）**：
  | # | 対応 | 備考 |
  |---|---|---|
  | N-1-a | **リクリックとカットオーバー当日のタイムライン合意**（停止時刻・退避着手/完了時刻・受渡方法・連絡体制・時間外/休日対応の可否と費用） | W-5。契約・見積の要否も含めて早期に確認 |
  | N-1-b | **移行リハーサルを本番相当データで最低2回**実施し、③④の所要時間を実測 | 1回目=手順検証、2回目=時間確定。実測値がダウンタイム見積りの根拠 |
  | N-1-c | **退避データの形式・受渡方法・暗号化/鍵を事前確定**し、**リハーサルと本番で同一形式**にする | 個人情報を含むため受渡経路は Q-A（PII取扱ルール）と整合 |
  | N-1-d | **許容ダウンタイムの業務合意**（営業・BW・代理店。停止告知の文面と告知タイミング） | R8 運用準備（release H-5）と連動 |
  | N-1-e | **切り戻し手順と発動基準・依頼ルートの明文化**（誰が何分で判断し、誰がリクリックへ連絡するか） | release I-3。リクリック側の対応可否も N-1-a で合意 |
  | N-1-f | **差分同期の要否検討**（ダウンタイムが業務上許容できない場合、事前フル投入＋当日差分のみ、の方式が取れるか。旧環境側の更新日時カラムの有無に依存＝要調査） | 実測ダウンタイムが許容値を超えた場合の代替案 |

- **計画上の位置づけ**：**R7 の「本投入(load)」はカットオーバー当日作業である**という前提を明示する。R7 の準備工程（ETL 基盤・名寄せ表・再エクスポート）を今から進めるのは変わらないが、**それだけでは移行は完了しない**。

### `basic-design.md` 1〜7章との突合（2026-07-27 実施・R フェーズへ読み替え）

| 基本設計章 | 受け皿（R） | 突合結果・補足 |
|---|---|---|
| §1 ユーザ管理 | R1（実装済み）/ R6（P4-7 運用整理） | ユーザ CRUD・検索・`is_active` は R1 実装済み（無効ユーザはログイン不可）。物理削除との役割分離・代理店/代理店グループ固定権限・セッション失効の運用ポリシーは未整理（P4-7 → 04 未反映） |
| §2 ログイン管理 | R0/R3/R4（実装済み）/ Q-30 | 管理画面の再設定（Devise recoverable）・失敗制御（lockable + rack-attack）実装済み。メールOTP は全画面必須（Q-23）で実装済み。受注入力は代理店CD＋営業担当者CD で PW なし → §2-1「営業担当者のパスワード再設定」は現方針と矛盾し Q-30 で確認 |
| §3 権限管理 | R0/R1（実装済み）/ Q-31 | RBAC + Pundit スコープ実装済み。T-2/T-3 是正済み。代理店ログインメールの扱いは Q-31。`organizations` 前提は不採用（T-6） |
| §4 顧客一覧 | R2（実装済み）/ R6（P4-2 統合ビュー・P4-4 名寄せ）/ Q-F | 参照範囲は R2 で Pundit 適用済み。商材横断ビュー・名寄せは R6。商材増（Q-F 決定）→ 納品日別テーブルは未実装（G-1・04 R6） |
| §5 顧客詳細 | R2（実装済み）/ R4（マイページ最小）/ R6（P4-9 拡充・P4-29 退会）/ Q-34 | 155項目・37カラムは R2 実装済み。表示/編集権限は Pundit。マイページ拡充・通常退会は R6（04 未反映） |
| §6 申込登録 | R3（実装済み）/ R5（P3-3 署名・P3-12/13 重説・確認書）/ Q-32・Q-33 | 動的マッピング・フォームビルダーは R3 実装済み。BRIDGE_PLUS 155項目の突合は未（04 R3 要確認）。署名・重説・確認書は R5 |
| §7 決済連携 | R5 / Q-7・Q-25〜27・Q-33・Q-36〜39 | 基本設計は「API ドキュメント待ち」の古い状態。`payment-integration.md` が正。実装はモック先行（R5）、実結線は開通処理・HMAC キー取得後（release D-1） |

---

## 3. フェーズ定義

### 3-1. Rails 版フェーズ R0〜R8（正は 04。ここは概要のみ）

| R | 内容 | Laravel 対応 | 状態（2026-08-19） |
|---|---|---|---|
| R0 | 基盤: rails new・Docker・CI・認証（Devise+メールOTP+IP許可リスト）・**認可RBAC移植**・監査ログ・Pundit 基盤・テストハーネス | P0 + P4-15/16/17 + ftlog 移植 | ✅ 完了 |
| R1 | 組織・アカウント: 代理店G/代理店/営業担当者/契約条件/ユーザ + **Pundit スコープ** + CSV 取込 | P1 前半 + P2-10 + P4-1 | ✅ 完了 |
| R2 | CRM 中核: 顧客/店舗/案件/作業詳細 + 商材マスタ群 + 選択肢/ステータス + 採番 + 検索/pagy/CSV 出力 | P1 後半 + P2-4 | ✅ 完了（販売許可 UI・Store 検索等の見送り事項は 04） |
| R3 | 申込フォーム: 営業ログイン + OTP・動的マルチステップ・申込トランザクション・フォームビルダー | P2（拡張後仕様） | ✅ 完了（155項目突合は未） |
| R4 | 問い合わせ・通知: Inquiry 系（掲示板統合）・一斉通知・アプリ内通知（Solid Cable）・マイページ最小 | P1 残 + P4-8 + P4-14 一部 | ✅ 完了（返信テンプレート＝FAQ は未・要確認） |
| R5 | 契約フロー・決済: 状態機械・ネットムーブ連携・契約書PDF・署名・不備/差戻し/確認コール・入力チェック設定・KW 自動選定・重説・確認書 | P3 全部 | ⬜ **未着手**（着手前チェックリスト = Q-25〜27・Q-35〜39・Q-D・Q-B。04 末尾） |
| R6 | 運用強化: 名寄せ・一括更新・統合ビュー・集計・遅延検知・自動キャンセル・CSV 取込・ガルーン・メンション・通知一覧・CSV プロファイル・遷移バリデーション | P4 群 | ⬜ 未着手（要件ごとに個別判断） |
| R7 | データ移行: ETL（rake）・掲示板アーカイブ・名寄せ・カットオーバー当日 load | P5-5 | ⬜ 未着手（別プロジェクト切り出し・決定F。設計済み） |
| R8 | 品質保証・リリース準備: デプロイ/CI-CD・監視ログ・法務・本番接続審査・運用教育・UAT/性能/セキュリティ診断・カットオーバー計画 | P5（-5 以外） | ⬜ 未着手（`release-readiness.md` A〜J。法務(G)・本番審査(D-1)・移行(B) は R5 と並行着手） |

### 3-2. 旧Laravel フェーズ P0〜P5 → R 対応表（参考・圧縮版）

各 P タスクが R のどこに吸収されたか。**「04 未反映」= 04-implementation-plan.md に対応タスクが無い（本書のサマリで 04 反映を提案）**。

#### P0 基盤 → R0（✅）／P1 管理画面 CRUD → R1/R2/R4（✅）

#### P2 申込フォーム → R2/R3

| P | 内容 | R / 状態 |
|---|---|---|
| P2-0 | 業務フロー93スライド分析（`business-flow-analysis.md`）。残 P2-0-g = G-1〜G-9 の各設計書反映 | ✅ 分析済み。G-1〜G-9 反映確認は 04 R6 に記載 |
| P2-1 | target_table/target_column ＋ 3次元編集権限（editable_by_tier / lock_after_status） | ✅ R3 実装済み（FormField） |
| P2-2 | processApplication の動的マッピング化 | ✅ R3（`Form::ApplicationSubmissionService`） |
| P2-3 | mapping §7 #5〜7 の未決定事項確定 | ⚠️ **04 未反映**（`form-template-mapping.md` §7 の残論点。R3 要確認と併せて処理） |
| P2-4 | customers 37 カラム追加・netmove 会員ID | ✅ R2 実装済み |
| P2-5 | OptionGroup シーダー（属性1-11 等・`legacy-research/05` §4） | ⚠️ **04 未反映**（`db/seeds.rb` は RoleSeeder/StatusSeeder のみ。R7 初期データ or R8 release I-6） |
| P2-6 | FormTemplate へ BRIDGE_PLUS フィールド追加 | 🔶 04 R3「要確認」（155項目突合）として記載。テンプレ実データ投入は未 |
| P2-7 | step-n.vue の動的バインディング | ✅ R3（ERB 動的レンダリング） |
| P2-8 | フォームビルダーで BRIDGE_PLUS テンプレート設定 | 🔶 UI は R3 実装済み。BRIDGE_PLUS テンプレ定義の投入は **04 未反映**（P2-6 と一体で R3 後続 / R7） |
| P2-9 | 案件契約登録の入力フィールド突合・バリデーション整理 | 🔶 `Form::DynamicFormValidator` は R3 実装済み。突合は 04 R3 要確認に含意 |
| P2-10 | T-2/T-3 解消 | ✅ R1/R2 |

#### P3 契約フロー → R5（全件 04 R5 に記載あり）

P3-1 決済設計 / P3-2 決済実装（決済専用キュー・リトライ無効化含む）/ P3-3 署名 / P3-4 案件ステータス状態機械 / P3-5 不備チェック / P3-6 差戻し / P3-7 確認コール / P3-8 契約書PDF / P3-9 契約書参照・DL・メール / P3-10 入力チェック設定 / P3-11 KW 自動選定 / P3-12 重説チェック / P3-13 申込確認メール・確認書 → **すべて R5**。実質順序（P3-1 → P3-2(a〜d,f〜j) → P3-12/13 → P3-4 → P3-2-e → P3-5〜9。ただし重説は状態機械設計後）は 04 R5 に反映済み。
- ⚠️ P3-7 の「音声ログ連携」（P4-24）と P3-2 の「請求用受注データ CSV」実装先は 04 で要確定扱い。

#### P4 業務運用機能 → R0/R1/R4/R6

| P | 内容 | R / 状態 |
|---|---|---|
| P4-1 | 代理店・グループのレコードレベル参照制御 | ✅ R1/R2（Pundit `AgencyScoped`）。通知宛先検索・問い合わせ・マイページの横断テストは release F-3 |
| P4-2 | 顧客一覧の商材横断 統合ビュー | R6（04 記載あり） |
| P4-3 | 項目一括更新 | R6（04 記載あり） |
| P4-4 | 顧客統合（名寄せ）`customer-merge-design.md` | R6（04 記載あり・並行処理 spec 必須） |
| P4-5 | 選択肢グループ等の定義データ再整理 | ⚠️ **04 未反映**（P2-5 と一体。R6 or R7 初期データ） |
| P4-6 | 案件検索へのメールアドレス条件追加 | ⚠️ **04 未反映**（R2 の Order 検索は `order_number` ILIKE のみ。R6 小改修） |
| P4-7 | ユーザ無効化の運用整理（物理削除との役割分離・固定権限・セッション失効） | ⚠️ **04 未反映**（`is_active` は R1 実装済み。運用整理は R6） |
| P4-8 | 代理店向け通達／顧客向け一斉通知 | ✅ R4 |
| P4-9 | マイページの機能拡充 | ⚠️ **04 未反映**（R4 は最小構成のみ。R6） |
| P4-10 | T-4 の解消 | 🔶 03§8-2（R2 完了後に CEO へ再分割要否を提案・未提案） |
| P4-11 | バックヤード追加フィールド（未収・お纏め請求・備考・予備欄） | 🔶 未収情報のみ 04 R2 追加タスク。お纏め請求・備考・予備欄は **04 未反映**（R6） |
| P4-12 | 画面ごとのデータ出力カスタマイズ（`export-profile-design.md`） | R6（04 記載あり） |
| P4-13 | メンション（問い合わせのみ・Q-18） | R6（04 記載あり） |
| P4-14 | 通知管理・通知一覧（既読・イベント別 ON/OFF・チャネル別・再送/失敗記録・Q-21） | 🔶 R4 で SystemNotification/一斉通知/InquiryRecipientRoute 実装済み。既読管理・イベント別 ON/OFF・失敗記録は R6「通知一覧強化」（04 記載あり） |
| P4-15 | ログイン履歴 | ✅ R0（AuditLog 絞り込みビュー） |
| P4-16 | 監査ログ強化（差分・IP・request_id・検索・CSV・契約/決済/署名の必須イベント一覧） | 🔶 差分・IP・request_id は R0 実装済み。**監査ログ検索/CSV 画面と R5 必須イベント一覧は 04 未反映**（R6 / R5） |
| P4-17 | IP 許可リスト＋メールOTP | ✅ R0/R3/R4 |
| P4-18 | 遅延案件の検知・通知・一覧＋ログイン時ポップアップ | R6（04 記載あり） |
| P4-19 | 自動キャンセル/クローズ | R6（04 記載あり） |
| P4-20 | 集計・レポーティング | R6（04 記載あり） |
| P4-21 | 連携状況記録＋連携エラー時の自動アウトバウンドメール | ⚠️ **04 未反映**（R6「等」に含意のみ） |
| P4-22 | 外部CSV取込（root / GBP / OBIC7） | R6（04 記載あり） |
| P4-23 | GBPアカウント権限管理・受注完了経過管理 | ⚠️ **04 未反映**（R6） |
| P4-24 | 対応音声ログ管理（容量・法務要確認） | ⚠️ **04 未反映**（R6。P3-7 確認コールと連動） |
| P4-25 | ガルーン API 連携（Q-G2） | R6（04 記載あり） |
| P4-26 | 初回運用レクチャー管理 | ⚠️ **04 未反映**（R6） |
| P4-27 | KW 管理（P3-11 とは別） | ⚠️ **04 未反映**（R6） |
| P4-28 | 代理店管理画面での資料共有フル版 | ⚠️ **04 未反映**（SalesMaterial は R2 実装済み。フル版 = R6） |
| P4-29 | 顧客利用停止（退会）と退会済み表示/検索（Q-34） | ⚠️ **04 未反映**（R6） |

#### P5 品質保証・リリース準備 → R7/R8

| P | 内容 | R / 状態 |
|---|---|---|
| P5-1 | 自動テスト拡充・CI DB smoke | 🔶 R0 基盤・R1〜R4 spec 済み。E2E・migrate/rollback smoke は R8（release F-4/F-9） |
| P5-2 | バグチェック・手動テスト・UAT | R8（04 記載あり） |
| P5-3 | インフラ・デプロイ基盤 | R8（04 記載あり。PostgreSQL/Kamal 前提へ置換） |
| P5-4 | システム利用マニュアルの Web 提供＋生成の仕組み化（Q-20） | ⚠️ **04 未反映**（R8「運用教育」に含意のみ。release H-1） |
| P5-5 | データ移行（ETL・名寄せ・load） | R7（04 記載あり） |
| P5-6 | 情シスへのリスク連携（AWS 構成・DNS・S3/RDS・監視・PII・ガルーン） | 🔶 R8「法務」に含意。情シス連携は **04 に明示なし**（release G-2） |
| P5-7 | 法務・コンプライアンス | R8（04 記載あり） |
| P5-8 | バックヤード作業マニュアル | ⚠️ **04 未反映**（R8。release H-2） |
| P5-9 | 監視・ログ・バックアップ | R8（04 記載あり） |
| P5-10 | セキュリティ（脆弱性診断・PCI DSS・PII ゲート・シークレット・アクセス制御） | 🔶 R8「UAT/性能診断」にセキュリティ診断が明示されていない → **04 に明示追加要**（release C） |
| P5-11 | リリースプロセス（カットオーバー・ロールバック・Go/No-Go・ハイパーケア） | R8（04 記載あり） |
| P5-12 | 性能・可用性 | R8（04 記載あり） |
| P5-13 | 月次レポート作成・送付（別意思決定と連動） | ⚠️ **04 未反映**（R6 or スコープ外判断） |
| P5-14 | ネットムーブ本番接続審査・契約 | R8（04 記載あり） |
| P5-15 | 運用準備（教育・移行案内・障害時業務継続） | R8（04 記載あり） |

---

## 4. 依存関係とクリティカルパス（R 基準）

```
R0 ─ R1 ─ R2 ─┬─ R3（申込フォーム）──┐
              └─ R4（問い合わせ・通知）─┴─ R5（契約フロー・決済）─ R8（QA・リリース）
                                          R6（運用強化）は R5 と並行可（要件ごとに判断）
                                          R7（データ移行）は R2 スキーマ確定済みのため準備工程は今から可・本投入はカットオーバー当日

  ┌ 今から並行で走らせる（リリース日を律速する長リードタイム作業）─────┐
  │  R7 準備工程（ETL 基盤・再エクスポート・名寄せ表・掲示板アーカイブ設計）  │
  │  R8-G 法務・コンプライアンス（決済フロー確認・利用規約・特商法）        │
  │  R8-A 本番構成決定（Q-40）・ステージング・デプロイ方式（Kamal 採否）    │
  │  R8-D-1 ネットムーブ本番接続審査・契約                                │
  └──────────────────────────────────────────────────────────────┘
```

**機能のクリティカルパス**：`R5 着手前チェックリスト確定（Q-25〜27・Q-35〜39・Q-D・Q-B）→ R5（決済 → 重説/確認書 → 状態機械 → 不備/差戻し/確認コール/契約書）→ R8`
**リリースのクリティカルパス**：**R7（データ移行）・R8-G（法務）・R8-D-1（本番接続審査）** が律速。今から並行着手。
R7 の律速は **現行DB再エクスポート＋名寄せ表＋カットオーバー当日合意（W-5/N-1-a）** の3点。
⚠️ **リリース日そのものがリクリックのカットオーバー当日作業に律速される**（§2 N-1）。移行リハーサル（N-1-b）の実測ダウンタイムも Go/No-Go の前提条件。

---

## 5. 優先度の考え方（R 基準）

| 優先度 | 基準 | 該当 |
|---|---|---|
| 最優先 | 業務が回らない／後回しほど手戻り／リードタイムが長い | R5 全般（着手前チェックリスト含む）、R7 準備工程、R8-G 法務、R8-D-1 本番接続審査、T-9/T-11（本番前セキュリティ小改修） |
| 高 | 契約フローの前提・R5 の設計を左右 | Q-B 呼称統一（T-8）、G-1 納品日別テーブル要否、R8-A 本番構成決定（Q-40） |
| 中 | 運用効率 | R6（名寄せ・一括更新・統合ビュー・遅延検知・集計・CSV プロファイル）、R8-E 監視、R8-C セキュリティ診断 |
| 低 | 後付け可能 | P4-11 残り（お纏め請求・備考・予備欄）、P5-8 バックヤードマニュアル、P5-13 月次レポート |

---

## 6. 進捗サマリ

| フェーズ | 状態（2026-08-19） |
|---|---|
| R0 基盤 | ✅ 完了（見直し残: `verify_authorized` 導入 = T-11） |
| R1 組織・アカウント | ✅ 完了（見直し残: CSV 取込履歴の可視化） |
| R2 CRM 中核 | ✅ 完了（見直し残: 販売許可 UI・Store 検索/CSV・Q-B 呼称・未収情報要否・PII 分類A 方針の文書化） |
| R3 申込フォーム | ✅ 完了（見直し残: セッション強化 = T-9・BRIDGE_PLUS 155項目突合） |
| R4 問い合わせ・通知 | ✅ 完了（見直し残: 返信テンプレート/FAQ 要否・通知マトリクス未決セルの整合確認） |
| R5 契約フロー・決済 | ⬜ 未着手（**着手前ブロッカー = CEO 確認事項**。04「次のアクション」5） |
| R6 運用強化 | ⬜ 未着手（04 未反映の P4 タスクあり → §3-2） |
| R7 データ移行 | ⬜ 未着手（設計済み。別プロジェクト切り出し） |
| R8 QA・リリース | ⬜ 未着手（`release-readiness.md` を Rails 版へ改訂済み。法務・本番審査・移行は今から並行） |

---

## 7. ftlog 参照機能（Rails 版では直接移植・R0/R4 で実装済み）

参照元：`/home/fujisawa/project/ai-auto-company/projects/ftlog`（Rails）。旧 `ftlog-port.md`（Rails→Laravel 変換設計）は削除済み。Rails 版は **ftlog 本体を一次情報として直接移植**した。

| 旧 D 番号の論点 | Rails 版の状態 |
|---|---|
| メールOTP（Q-19 一本化・Q-23 全画面必須） | ✅ R0/R3/R4: `OtpAuthenticatable` concern（otp_code_digest SHA256・10分・5回）を User / Customer / SalesRepresentative に適用。**remember me の抜け穴**は Devise `rememberable` を採用していないため構造上発生しない |
| IP 許可リスト（Q-17 システム全体で1つ） | ✅ R0: `IpAllowlistEntry.allows?(request.remote_ip)`・空リスト=全員 OTP。**リバースプロキシ配下の `remote_ip` 信頼設定（旧 TrustProxies）は R8 で必須**（release A-5） |
| ログイン履歴 | ✅ R0: AuditLog の絞り込みビュー（`admin/login_histories`） |
| 監査ログ（Q-16 activitylog 拡張 → Rails は Auditable 移植・Q-22 5年） | ✅ R0: `Auditable`/`AuthAuditable`/`TracksUser`/`Current`。検索/CSV 画面は R6 |
| 通知テーブルの名前衝突（メール配信記録 vs アプリ内通知） | ✅ R4: `notifications`（配信）と `system_notifications`（アプリ内）を分離。Solid Cable でリアルタイム、30日 prune は Solid Queue recurring |
| メンション（Q-18 問い合わせのみ） | ⬜ R6 |
| マニュアル（Q-20 顧客まで全対象） | ⬜ R8（04 未反映 → 追加要） |

---

## 8. 未決定事項（全件保持・状態列を追加）

凡例: **未決** / **決定済み（日付）** / **保留**。「R / 04 参照」列は 04-implementation-plan.md の該当フェーズ・チェックリスト。

| # | 論点 | 状態 | R / 04 参照 | 備考 |
|---|---|---|---|---|
| Q-1 | リリース目標時期・全体スケジュール | 未決 | R8 | リクリック当日作業合意（W-5/N-1-a）と移行リハーサル実測（N-1-b）後でないと確定不可 |
| Q-2 | 段階リリースか一括か | 未決 | R8（release I-1） | 同上 |
| Q-3 | 開発体制（人数・役割） | 未決 | R8 | アプリ実装/インフラ構築/データ移行/外部調整/法務・情シス窓口/UAT/リリース判定の役割分担 |
| Q-4 | データ移行の要否・規模 | ✅ 決定済み（2026-07-24） | R7 | 移行必須・規模判明（`legacy-research/08`） |
| Q-5 | 顧客詳細のタブ構成・表示フィールド | 部分決定 | R2 実装済み / R6 | 155項目で緩和。R2 の詳細画面は実装済み・タブ構成の UI 精査は R6 |
| Q-6 | 顧客重複時の対応方針 | 未決 | R6（名寄せ） | `customer-merge-design.md` は統合手順。重複「検知」時の運用は未決 |
| Q-7 | 支払方法（クレカのみ / 口座振替等） | 未決 | R5 | |
| Q-8 | 手書き署名の取得手段 | 未決 | R5 | |
| Q-9 | グループ兼代理店の NestedSet 表現 | 構造上解消・業務要件は要確認 | R1 実装済み | Rails 版は NestedSet 不採用（AgencyGroup/Agency 2階層 + `users.agency_group_id/agency_id`）。「グループ兼代理店」を業務上どう持つかは未確認 |
| Q-10 | テスト方針（フレームワーク/カバレッジ目標） | 部分決定 | R0 実装済み / R8（release F-8） | RSpec + FactoryBot + 認可ハーネスは決定・実装済み。カバレッジ目標値は未決 |
| ~~Q-11〜13~~ | 顧客統合（不可逆か／退会Aの扱い／統合キー有効期限） | ✅ 決定済み（2026-07-26・D-12） | R6 | 不可逆／論理削除＋認証・メールのみ無効化／24hワンタイム・5回失効（`customer-merge-design.md`） |
| ~~Q-14~~ | 出力定義の管理方法（config / DB管理） | ✅ 決定済み（2026-07-26・D-13） | R6 | config 管理 v1・将来ハイブリッド移行可（`export-profile-design.md`） |
| Q-15 | アシスト納品用エクスポートの具体フォーマット | 未決（ヒアリング起案承認済み D-10） | R6 | 文面作成→承認キューへ |
| ~~Q-16~~ | 監査ログの実装方式 | ✅ 決定済み → R0 実装済み | R0 | Rails 版は ftlog `Auditable` 移植（activitylog 拡張の等価） |
| ~~Q-17~~ | IP許可リスト・2FA の設定単位 | ✅ 決定済み → R0 実装済み | R0 | システム全体で1つ |
| ~~Q-18~~ | メンションの適用対象 | ✅ 決定済み | R6（未実装） | 問い合わせメッセージのみ |
| ~~Q-19~~ | OTP 方式 | ✅ 決定済み → R0 実装済み | R0/R3/R4 | メールOTPに一本化・TOTP なし |
| ~~Q-20~~ | マニュアルの対象読者 | ✅ 決定済み（2026-07-26・D-7） | R8（04 未反映） | 顧客まで全対象（マイページ操作ガイド含む） |
| Q-21 | 通知の受信者マトリクス | 未決（R4 実装先行） | R4 実装済み / R5・R6 着手前チェック | `notification-matrix.md` の ? セル（E1/E3/E6/E7/E8/E12 等）解消、決済失敗通知（E6→R5）、自動キャンセル通知（E8→R6）、申込確認/契約確認メールの Cc 方針 |
| ~~Q-22~~ | 監査ログの保存期間 | ✅ 決定済み（2026-07-26・D-6） | R0 | 5年（prune 無し） |
| ~~Q-23~~ | 二要素認証を必須にする対象 | ✅ 決定済み（2026-07-26・D-5）→ R0/R3/R4 実装済み | R0/R3/R4 | 全画面必須（03§8-2 で実装方式決定） |
| Q-24 | 決済の課金モデル | ✅ 決定済み | R5（請求 CSV 実装先は R5 着手時確定） | 月額継続課金。新システムは会員登録/1円与信＋請求用受注データ CSV まで。売上処理は TBSS 運用継続（D-P8） |
| Q-25 | 返金・キャンセルの業務要件 | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト / release D-3 | |
| Q-26 | 信販（アシスト信販）を決済フローに含めるか | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト | |
| Q-27 | 決済障害時の縮退運用 | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト / release H-6 | |
| Q-28 | 外部ツール（Teams・掲示板・S-RAPO）を代替するか現行維持か | 未決 | R6 | 掲示板は Q-C で問い合わせ統合済み。Teams/S-RAPO は未決 |
| Q-29 | 電子契約を契約書生成（P3-8）と統合するか外部継続か | 未決 | R5 | |
| Q-30 | 受注入力画面（営業担当者CD認証）にパスワード再設定を持たせるか | 未決（実装は PW なし＋OTP） | R3 実装済み | basic-design §2-1 は営業担当者の PW 再設定を想定。現実装は代理店CD＋営業担当者CD＋メールOTP で PW を持たない。設計書側を実装に寄せるか要確認 |
| Q-31 | 代理店/代理店グループのログインメールを通知先メール（email_1〜5）と兼用するか専用フィールドか | 未決 | R1 実装済み（`users.email` でログイン）/ R6 | 現実装は User の email = ログインID。代理店エンティティの通知先メールとの関係は未整理 |
| Q-32 | 申込入力端末・URL 受け渡し方式 | 未決 | R3 実装済み（営業端末前提）/ R5 | 顧客スマホへの URL 送付方式は署名（P3-3）・確認書導線に影響 |
| Q-33 | 月額料金等を顧客に見せない方針と、ネットムーブ checkout の `item_name`/金額表示の整合 | 未決 | R5 | |
| Q-34 | 通常の顧客利用停止（退会）の扱い | 未決 | R6（P4-29・04 未反映） | 顧客統合時の退会化とは別に定義 |
| Q-35 | 重説チェック・申込確認メール/確認書の未決事項（項目/実施者/タイミング/宛先/Cc/再送/版管理/同意証跡） | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト / `contract-confirmation-docs.md` Q-1〜9 | |
| Q-36 | 決済トランザクションの紐づけ単位（顧客/案件/おまとめ請求親） | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト | `payment_transactions.order_id` 直結では N案件:1決済を表現できない可能性 |
| Q-37 | ネットムーブ受注コード `jutyu_cd` の桁数・採番・再利用可否 | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト / `legacy-research/02` | 11桁/12桁の資料矛盾 |
| Q-38 | 決済結果の確定手段（照会API/Webhook/取引履歴CSV） | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト / release D-2 | ret_url に結果コードが返らない |
| Q-39 | ステージング環境での決済検証方式 | **未決（R5 着手前ブロッカー）** | 04 R5 チェックリスト / release D-1 | 商用カード／Mock 固定／IP 制限下で実通信 |
| Q-40 | 本番構成方式（単一VM+Kamal / VM+マネージドDB / コンテナ基盤等） | 未決 | R8（release A-13） | 旧「AWS 構成案（EC2/ALB/ECS）」を一般化。`basic-cost.md` は削除済み・再試算要 |
| Q-41 | バックアップ保持期間・RTO/RPO・ストレージ保管物復旧方針 | 未決 | R8（release E-4） | PostgreSQL 4 DB のうち primary 必須 |
| Q-42 | ドメイン取得/移管、DNS 管理、HTTPS 証明書方式 | 未決 | R8（release A-9） | Kamal proxy（Let's Encrypt）or 終端側 TLS |
| Q-43 | ステージング環境で使用するデータ種別（マスク済み/本番相当/実PII禁止） | 未決 | R8（release A-2/C-5） | Q-A（PII ルール）に連動 |
| Q-44 | 掲示板アーカイブの検索要件・保持期間・アクセス権・添付移行方針 | 未決 | R7 | Q-C は実装方針決定済み。参照専用アーカイブの運用要件は別途 |
| Q-A | 原資料の外部認証情報・実顧客個人情報の取り扱い | 保留（D-3・2026-07-26） | R8（release C-5/G-8） | `pii-handling-rules.md` ドラフトあり。確定前は本番相当データを本番/ステージングへ置かない |
| ~~Q-B~~ | 「顧客ステータス」の呼称と customer_statuses / order_statuses の関係整理 | ✅ 決定済み（2026-07-26・D-8）だが **実装が中途半端（T-8）** | 04 R2 追加タスク・CEO 確認事項 | 案A（案件/申込/契約ステータスの3語・テーブルリネームなし）。`order_statuses` 側のみ適用済み。`customer_statuses` を「申込ステータス」へ統一するかの再確認が 04「次のアクション」に載っている |
| ~~Q-C~~ | 掲示板4種の実装方針 | ✅ 決定済み（2026-07-26・D-11）→ R4 実装済み | R4 / R7 | 問い合わせ統合（Inquiry 拡張）＋過去42万件は参照専用アーカイブ（R7） |
| Q-D | 顧客SNSアカウント・パスワードの保持可否（保持なら暗号化） | 部分実装・方針未記録 | R2 実装済み / 04 R5 着手前チェック | `OrderWorkDetail` 8 カラムは `ActiveRecord::Encryption` で暗号化済み。Customer 本体 PII（分類A）を暗号化しない方針の正式記録が未（04 R2 見送り事項）。移行時の平文 SNS 認証情報の扱いは R7 |
| Q-E | AI投稿代行の発注（外部フォーム22項目）を自動化できるか | 未決 | R6 | |
| ~~Q-F~~ | 商材が今後増えるか（増えるなら納品日は別テーブル化） | ✅ 決定済み（2026-07-26・D-4） | R5/R6（04 R6 G-1 要否判断） | 増える見込み→納品日は別テーブル化。**実装は未**（`work_completed_at` 単一カラム） |
| Q-G2 | ガルーン API 連携の可否（情シス確認必須） | 保留（D-9・2026-07-26） | R6 / R8（release G-2） | |
| Q-H | ステップ配信（解約抑止メール・機能57-58）の実装要否 | 検討段階 | R6 | |
| Q-背1〜4 | 月次レポートのスコープ／プラン集約時期／契約期間確定／音声ログ | 未決 | R6 / P5-13（04 未反映） | `legacy-research/01` §5 |
| Q-移1〜5 | 掲示板移行範囲／名寄せ精度／不備データ／断面／施工担当者 | 未決 | R7 | `legacy-research/09` §9。加えて 04 R7 の Q-移7/15/18・DM-7 |

---

## 9. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版作成。既存設計書とコードの実装状況を突合し、P0〜P5 のフェーズを定義 |
| 2026-07-24 | P4-12（データ出力カスタマイズ）追加、P4-4（顧客統合）詳細化 |
| 2026-07-24 | §7 ftlog移植方針を新設。P4-13〜17 追加、P5-4 再定義。Q-16〜19 を決定 |
| 2026-07-24 | `design/payment-integration.md` 新規（P3 最大の作業）。Q-24〜27 起票 |
| 2026-07-24 | P2-0（業務フロー93スライド分析）追加・完了。Q-A〜F 起票。掲示板4種・G-1〜9 |
| 2026-07-24 | `design/release-readiness.md` 新規（非機能10領域）。P5 を P5-1〜13 へ拡充。T-1 訂正 |
| 2026-07-24 | 現行資料の徹底調査 `design/legacy-research/`（00〜09）。**W-1（決済）・W-2・W-3 が資料内で解消**。運用機能 P4-18〜25 追加。3次元編集権限を P2-1 へ。データ移行整形（09）。ガルーン連携 P4-25・Q-G2 |
| 2026-07-24 | ⚠️ laravel ディレクトリ差し替え（15:11）で design 配下の設計書群が一度消失。会話コンテキストから全ファイルを再作成し、04_jasmin_base へコミット・push |
| 2026-07-26 | 深掘りレビュー反映（`development-plan-review-20260726.md`）：P3-2-e 順序・P4-16 前倒し・T-2/T-3 を P2-10 へ繰り上げ・P5-5 準備/本投入分割（P2-4依存）・P5-14/15・P3-12/13・P4-26〜28・Q-H 起票・Q-A/Q-D 注記・§0/T-1 訂正 |
| 2026-07-26 | **仕様意思決定（D-1〜D-13・`drafts/仕様-decision-sheet-20260726.md`）**: Q-B/Q-C/Q-F/Q-22(5年)/Q-23(全画面)/Q-20/Q-11〜13/Q-14 を決定。ネットムーブ依頼・再エクスポート依頼（リクリック宛）の送信承認。Q-15ヒアリング起案承認。D-3(PIIルール)・D-9(ガルーン起案) は保留 |
| 2026-07-27 | `basic-design.md` 1〜7章を本計画へ集約。ユーザ管理/ログイン/権限/顧客一覧/顧客詳細/申込/決済の受け皿を明示し、P4-29 と Q-30〜34、T-6 を追加。P2-4完了・P3-2 WIPへ進捗更新 |
| 2026-07-27 | **DBバージョン方針を決定（仕様承認）**：全環境 MySQL 8.4 LTS。開発 docker を 8.2→8.4.10 へ更新し、マイグレーション8本の migrate/rollback/再migrate を実機検証。P5-3 へ反映。CI に MySQL サービスが無い問題を発見。自社実装の残作業を `impl-plans/_TODO-implementation.md` に記録（※Laravel 側限定。2026-08-14 の 03 決定A（PostgreSQL）で置換） |
| 2026-07-27 | **⚠️ 注意事項 N-1 を登録（仕様指摘）**：移行は「事前受領データを整形して投入」では成立せず、旧環境停止→リクリックが最終退避→整形→新環境投入をカットオーバー当日に他社経由で行う必要がある。W-5 追加、N-1-a〜f を起票し、P5-5・P5-11・リリースのクリティカルパスへ反映 |
| 2026-07-27 | requirements横断見直しのYES判定71件を反映。P3順序、P4-29範囲表記、P5-1/3/5/7/9/10/11/12/15詳細、AWS/SES/監視/バックアップ/PII/Go-No-Go、Q-35〜44を追加・更新 |
| 2026-08-14 | （brige-crm 側）03 構成論点 A〜F を CEO 決定（PostgreSQL / Hotwire+ERB / section 3区分 / prefix 除去 / rails new+選択移植 / 移行別フェーズ）。04 実装計画 v2 |
| 2026-08-15 | （brige-crm 側）01〜04 の突合レビュー（review-01〜04）。R8 新設。決定D 衝突・Q-23・form RBAC 統合方式を CTO 自律決定（03§8-2）。R0〜R4 着手 |
| 2026-08-18 | （brige-crm 側）R0〜R4 実装完了。R0〜R3 見直しレビュー（commit `3bb033f` `1e7a0ad` `50bd98d` `7cb7dc4` `06d8693`）、OTP バイパス修正（`2022d67`） |
| 2026-08-19 | 旧Laravel 側の設計ドキュメント 31 ファイルを brige-crm へ集約・精査（review-05）。**以後 requirements/ の正は brige-crm 側**。7 ファイル＋`impl-plans/` を削除 |
| 2026-08-19 | **本書を Rails 版へ全面改訂**：役割を「全体像・P→R 対応表・未決定事項台帳・変更履歴」に再定義（フェーズ詳細の正は 04）。§0 体系を Rails 版へ、§1 を Rails スタックへ、§2 を R0〜R4 実装済み内容へ更新し MySQL 8.4 決定を PostgreSQL へ置換、T-7〜T-11 を追加。§3 に P0〜P5→R0〜R8 対応表を新設し 04 未反映タスク（P2-3/P2-5/P2-8/P4-5/P4-6/P4-7/P4-9/P4-11 残/P4-16 残/P4-21/P4-23/P4-24/P4-26/P4-27/P4-28/P4-29/P5-4/P5-6/P5-8/P5-10/P5-13）を明示。§4〜§6 を R 基準へ。§7 を「ftlog 直接移植・実装済み」へ。§8 は全 Q を保持し「状態／R・04 参照」列を追加（Q-25〜27・Q-35〜39 を R5 着手前ブロッカーとして 04 と番号を揃えた） |
