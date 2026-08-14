# brige-crm アーキテクチャ構成検討（提案・ドラフト v1）

- 目的: Laravel実装（01参照）を Rails で再構築するにあたっての技術構成・設計方針の検討
- 参考: ftlog のアーキテクチャ（02参照）、`jasmin_laravel/requirements/`（機能仕様の正）
- 状態: **ドラフト。CEOレビューで確定させる（論点は §8）**

---

## 1. 基本方針

1. **機能仕様の正は Laravel リポジトリの `requirements/`**（basic-design.md / Column.md / legacy-research/）。実装コードは参考であり、負債（T-1〜T-5）は移植せず是正して作る
2. **認可・認証・監査・テストハーネスは ftlog の実装をベースに移植**（実績があり、Laravel側の同思想実装より成熟している）
3. **未実装機能（契約フロー・決済連携・参照制御）は「後付け」ではなく最初からスキーマ・設計に織り込む**（Laravel側で手戻りが懸念されていた箇所）
4. 単一テナント前提（ftlogのマルチテナント機構 acts_as_tenant は**移植しない**）

## 2. 技術スタック（提案）

| 項目 | 提案 | 根拠 |
|---|---|---|
| Ruby / Rails | **Ruby 3.4 / Rails 8.1**（ftlogと同版） | ftlogのコード・規約を最大流用 |
| DB | **PostgreSQL**（★論点A） | UUID主キー（`gen_random_uuid()`）・全文検索（pg_bigm）・ftlogパターン流用。現Laravel=MySQL 8だが移行はどのみちETL |
| 主キー | **UUID**（`id: :uuid`） | Laravel実装を踏襲（全モデルUUID） |
| フロントエンド | **Inertia Rails + Vue 3 + TypeScript**（★論点B・推奨） | 既存 Vue ページ資産（shadcn-vue・約25エンティティ分のCRUD画面）を概念ごと流用可。対抗案=ftlog式 Hotwire+ERB |
| CSS / UI | Tailwind CSS v4 + shadcn-vue（論点Bの帰結） | Laravel資産流用 |
| 認証 | **Devise**（複数スコープ: User / Customer）+ ftlog式メールOTP | Q-19（TOTP廃止→メールOTP）を最初から満たす。ftlogに実装・テストあり |
| 受注入力認証 | Deviseを使わず**独自セッション**（代理店CD＋営業担当者CD） | Laravel現行と同方式（FormAuth相当のconcern） |
| 認可 | **ftlog式エンドポイントRBAC**（レイヤー1）+ **Pundit**（レイヤー2） | §3参照 |
| キュー/キャッシュ/WS | **Solid Queue / Solid Cache / Solid Cable**（Redisレス） | ftlog実績。Horizon/Redis/Reverb相当をDBで代替し運用簡素化 |
| 監査ログ | **ftlogの Auditable concern 一式を移植** | activitylog相当。TRACKED_FIELDS宣言・request_id/IP付与・差分記録。保存5年（Q-22） |
| 状態機械 | 決済=Laravelの厳格設計を**手実装で忠実移植**（unknown≠failed、mark/confirm分離）。契約フローも同パターン | gem（AASM等）はunknown系の特殊遷移制御が歪むなら使わない |
| ページネーション | pagy（軽量） | ftlogはgem不在。新規選定 |
| 階層マスタ | closure_tree または ancestry（OptionValueツリー） | |
| PDF（契約書） | 要選定（grover / ferrum系 or prawn）— P3相当フェーズで決定 | |
| CSV | Ruby標準csv + 非同期ジョブ（Laravel CsvExport方式踏襲） | |
| テスト | **RSpec + FactoryBot**、request spec中心 + **ftlogの認可テストハーネス移植**（既定=実認可） | 回帰検出の要 |
| Lint/CI | rubocop-rails-omakase / brakeman / bundler-audit + **認可スキップ検出grepガード**（ftlog CI流用） | |
| Docker | db(pg) / web / worker(Solid Queue) / (vite ※論点B次第) / mailpit | ftlog compose + Laravel composeの合成 |
| デプロイ | 未定（社内インフラ次第。ftlogはKamal） | 本番要件確定後 |

## 3. 認可設計（本プロジェクトの核）

### 2層認可（ftlog移植・単一テナント簡素化）

```
レイヤー1: エンドポイントRBAC（操作可否）
  SystemPermission（ルートカタログ: controller/action/http_method/path/section/enabled）
  SystemRole（super_admin フラグ / portal フラグ / system=組み込み）
  SystemRolePermission（中間）/ UserSystemRole（多対多）
  ApplicationController before_action :authorize_system_permission!（フェイルクローズ）
  SystemPermissionChecker（判定サービス）
  SystemPermissionSyncService（ルート走査→カタログ自動同期・起動時実行）
  RoleSeeder（既定マトリクスをコードで宣言。ftlogのOrganizationRoleSeederから組織スコープを除去）
  権限マトリクス管理UI（permission_management / role_management）

レイヤー2: Pundit（レコード可否・参照スコープ）
  「代理店ユーザは自代理店のデータのみ」「グループユーザは配下代理店のデータのみ」を
  policy_scope で全一覧・詳細に最初から適用（Laravel側の最重要未実装 P4-1 を初期設計に組み込む）
```

### Laravel現行からの対応

| Laravel | brige-crm |
|---|---|
| spatie Permission（`Controller@method` 文字列） | SystemPermission（ルート署名。同思想・より厳密） |
| PermissionScannerService（コントローラ走査） | SystemPermissionSyncService（**ルーティングテーブル**走査・起動時自動） |
| CheckActionPermission ミドルウェア | ApplicationController before_action（フェイルクローズ） |
| ロール4種: admin / 実務運用者 / 代理店グループ用 / 代理店用 | 組み込みロールとして再定義（admin=super_admin フラグ）。**名称は維持**（変更禁止指定） |
| 権限マトリクス画面 matrix.vue | ftlogのマトリクスUIを論点Bのフロント方式で再実装 |
| レコード参照制御（未実装） | Pundit policy_scope で初期実装 |

### section の割当（ftlogの staff/customer を拡張するか）

- ftlog: `staff` / `customer`（portal） の2区分
- brige-crm のアクター: 社内（admin・実務運用者）/ 代理店グループ / 代理店 / 営業担当者（受注入力）/ 顧客（マイページ）
- 提案: section は `admin`（管理画面）/ `form`（受注入力）/ `mypage`（顧客）の3区分とし、代理店・グループの差は**ロール＋Punditスコープ**で表現（★論点C）

## 4. 認証設計

| 系統 | 方式 |
|---|---|
| 管理画面（User: 社内/代理店G/代理店） | Devise（database_authenticatable, recoverable, lockable, timeoutable）+ **ftlog式メールOTP**（otp_code_digest SHA256・10分・5回・secure_compare）+ rack-attack |
| 顧客マイページ（Customer） | Devise 別スコープ |
| 受注入力（営業担当者） | 独自セッション認証（代理店CD＋営業担当者CD）。SalesRepresentative は Devise 対象外 |

- 招待制/公開登録ブロック、ソフトデリート対応、Devise通知は deliver_later — ftlog踏襲
- ログイン履歴（login_histories）・IP許可リストも ftlog から移植可（Laravel側 P4-14〜16 の要件を先取り）

## 5. ドメインモデル方針

- テーブル・カラム設計は **`design/Column.md`（Laravel側）+ legacy-research のマッピングが正**。Laravel migrationは参考
- Laravel側の負債を**最初から是正**:
  - T-2: `sales_representatives.sales_rep_code` をグローバルユニークに
  - T-3: `contract_condition_id` は **受注（orders）側**に持たせる
  - T-5相当の残骸（nestedset / organizations画面）は持ち込まない
- 自動採番（C-xxxxxx / ORD{年}{連番} / INQ-xxxxxx）: `count()+1` を廃し、**採番テーブル＋行ロック or PostgreSQLシーケンス**で競合安全に
- モデル名は Rails 規約に正規化（例: `JasminCustomer`→`Customer`, `JasminOrder`→`Order` 等。`jasmin_` プレフィックスを外すか ★論点D）
- 決済（PaymentTransaction）は状態機械・ログテーブル含め忠実移植。ネットムーブ連携は `payment-integration.md` 準拠
- PII: WorkDetail の SNS認証情報等は **`ActiveRecord::Encryption` で暗号化保存**を既定にする（Q-D への先回り提案）
- フォーム定義（FormTemplate/Step/Field）は **P2拡張後仕様（target_table/target_column＋3次元編集権限）を初期スキーマに採用**

## 6. アプリ構造規約（ftlog踏襲）

- `app/controllers`（`admin/` `form/` `mypage/` のネームスペース）/ `models` / `policies` / `services`（ビジネスロジック集約）/ `jobs` / `mailers`
- `Current`（CurrentAttributes: user / ip_address / request_id）→ created_by/updated_by 自動セット（TracksUser相当）もここで
- モデル先頭に annotaterb スキーマ注釈
- コーディング規約: rubocop-rails-omakase。実装コメントは「何を・なぜ」を処理箇所に記述

## 7. テスト戦略

- RSpec + FactoryBot。request spec 中心
- **ftlogの認可テストハーネスを最初から導入**（既定=実認可・フェイルクローズ。`:skip_system_authorization` は明示時のみ）
- Laravel側の教訓（T-1: 中核業務テスト不在）を踏まえ、**決済状態機械・申込トランザクション・参照スコープのspecを必須化**
- CI: rubocop / brakeman / bundler-audit / rspec / 認可スキップ検出grep

---

## 8. 論点（CEO確認したい判断）

| # | 論点 | 選択肢 | 秘書の推奨 |
|---|---|---|---|
| A | DB | PostgreSQL / MySQL 8（現行Laravel） | **PostgreSQL**。UUID・全文検索・ftlogパターン流用。移行はどのみちETLなのでDB乗換コストは限定的。ただし社内運用標準がMySQLなら再考 |
| B | フロントエンド | ①Inertia Rails + Vue 3（Laravel資産流用） / ②Hotwire + ERB（ftlog式・ビルドレス） | **①**。25エンティティ分のVue画面・shadcn-vueの設計資産を活かせる。②は運用が軽いが全画面作り直し。※①の場合ftlogのビューヘルパー方式は shared props 方式（Laravel現行と同じ）に読み替え |
| C | 権限 section 区分 | staff/customer（ftlogそのまま） / admin/form/mypage（3区分） | **3区分**。受注入力（営業担当者）は独自認証でユーザ体系が別のため独立sectionが明快 |
| D | モデル命名 | `jasmin_` プレフィックス維持 / 外す（Customer, Order, Store…） | **外す**。brige-crm単体で完結する命名に。将来のサービス別分離は namespace で対応 |
| E | 移植の起点 | ゼロから rails new / ftlog をテンプレートに複製して削る | **rails new + ftlogから該当ファイルを選択移植**。ftlog複製はテナント機構・issue系の削除コストが高い |
| F | データ移行スコープ | 本設計に含める / 別プロジェクト化 | **別フェーズ切り出し**（legacy-research/ETL設計は流用）。ただしスキーマ設計時にマッピング整合は常時確認 |

---

## 9. 参照

- 01-laravel-current-analysis.md（現行Laravel分析）
- 02-ftlog-architecture-analysis.md（ftlog解剖・RBAC詳細）
- 04-implementation-plan.md（実装計画）
- Laravel側要件: `projects/boilerplate-vue-env/laravel/requirements/`（basic-design.md ほか）
