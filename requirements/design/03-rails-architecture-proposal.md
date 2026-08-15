# brige-crm アーキテクチャ構成検討（v2・論点確定済み）

- 目的: Laravel実装（01参照）を Rails で再構築するにあたっての技術構成・設計方針の検討
- 参考: ftlog のアーキテクチャ（02参照）、`jasmin_laravel/requirements/`（機能仕様の正）
- 状態: **v2 = 論点A〜F CEO決定反映（2026-08-14）。決定録は §8**
- 補足: 新規サービス名称（プロダクト名）は未定。リポジトリ名 brige-crm を仮称として使う

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
| DB | **PostgreSQL**（決定A） | UUID主キー（`gen_random_uuid()`）・全文検索（pg_bigm）・ftlogパターン流用。現Laravel=MySQL 8だが移行はどのみちETL |
| 主キー | **UUID**（`id: :uuid`） | Laravel実装を踏襲（全モデルUUID） |
| フロントエンド | **Hotwire + ERB（ftlog式・ビルドレス）**（決定B） | importmap-rails + propshaft + turbo-rails + stimulus-rails。ftlogのビュー資産（マトリクスUI・`can_access_system_action?`ヘルパー・レイアウト）をほぼそのまま流用可。Node/ビルドチェーン不要で運用が軽い。既存Vue画面は「画面仕様の参考」として読む |
| CSS / UI | **Tailwind CSS v4（tailwindcss-rails・Nodeレス）** | ftlog踏襲。compose に tailwind watch コンテナ |
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
| Docker | db(pg16+pg_bigm) / web / tailwind(watch) / worker(Solid Queue) / mailpit | ftlog compose 踏襲＋mailpit（Laravel composeから） |
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
| 権限マトリクス画面 matrix.vue | ftlogのマトリクスUI（ERB）をほぼそのまま流用（決定Bにより再実装不要） |
| レコード参照制御（未実装） | Pundit policy_scope で初期実装 |

### section の割当（決定C: admin / form / mypage の3区分）

- ftlog: `staff` / `customer`（portal）の2区分。brige-crm は認証系統が3つ（管理画面=User / 受注入力=営業担当者独自セッション / マイページ=顧客）あるため3区分に拡張する
- **設計意図（CEO確認済み 2026-08-14）**:
  1. **誤配線防止（フェイルクローズの第一関門）**: 権限チェックの最初に「このユーザ種別が入れる section か」を判定。管理ユーザへform権限の誤割当、顧客の管理画面ルート到達などを section 段階で構造的に遮断する
  2. **マトリクス画面の見通し**: ロール割当の編集対象は `admin` section のみ。`form` / `mypage` は「その認証系統でログイン済みなら通れる」固定運用（ロール×権限の割当対象にしない）。営業担当者・顧客はロールを持たないアクターのため、この扱いが自然
  3. **代理店/グループの差は section を増やさず表現**: 同じ admin section 内の違いなので、「見える範囲」=Punditスコープ、「押せる操作」=ロール割当で表現する。section はあくまで認証系統の仕切りに限定する
- 実装: SyncService がコントローラのネームスペース（`admin/` `form/` `mypage/`）から section を自動判定（ftlogの `portal/`→customer 判定の拡張）

## 4. 認証設計

| 系統 | 方式 |
|---|---|
| 管理画面（User: 社内/代理店G/代理店） | Devise（database_authenticatable, recoverable, lockable, timeoutable）+ **ftlog式メールOTP**（otp_code_digest SHA256・10分・5回・secure_compare）+ rack-attack |
| 顧客マイページ（Customer） | Devise 別スコープ |
| 受注入力（営業担当者） | 独自セッション認証（代理店CD＋営業担当者CD）。SalesRepresentative は Devise 対象外 |

- 招待制/公開登録ブロック、ソフトデリート対応、Devise通知は deliver_later — ftlog踏襲
- ログイン履歴（`login_histories`は独立テーブルではなく`AuditLog`をログイン系アクションで絞り込む画面。2026-08-15訂正）・IP許可リストも ftlog から移植可（Laravel側 P4-14〜16 の要件を先取り）

## 5. ドメインモデル方針

- テーブル・カラム設計は **`design/Column.md`（Laravel側）+ legacy-research のマッピングが正**。Laravel migrationは参考
- Laravel側の負債を**最初から是正**:
  - T-2: `sales_representatives.sales_rep_code` をグローバルユニークに
  - T-3: `contract_condition_id` は **受注（orders）側**に持たせる
  - Laravel現行の未使用残骸（nestedset / organizations画面。T番号なし。2026-08-15訂正: development-plan.mdの実T-5は「composer.jsonのnameがstarter-kitのまま」で無関係）は持ち込まない
- 自動採番（C-xxxxxx / ORD{年}{連番} / INQ-xxxxxx）: `count()+1` を廃し、**採番テーブル＋行ロック or PostgreSQLシーケンス**で競合安全に
- モデル名は Rails 規約に正規化（決定D: `jasmin_` プレフィックスを外す。`JasminCustomer`→`Customer`, `JasminOrder`→`Order` 等。将来のサービス別分離は namespace で対応。※プロダクト名は未定・確定後も内部モデル名は汎用名を維持）
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

## 8. 決定録（CEO決定 2026-08-14）

| # | 論点 | 決定 | 備考 |
|---|---|---|---|
| A | DB | **PostgreSQL** | UUID・pg_bigm全文検索・ftlogパターン流用。移行はどのみちETL |
| B | フロントエンド | **ftlog式 Hotwire + ERB（ビルドレス）** | 秘書推奨はInertia+Vueだったが、CEO判断でHotwire。ftlogのビュー資産・ヘルパー方式（`can_access_system_action?`）をそのまま流用でき、認可まわりの移植コストはむしろ下がる。既存Vue画面は画面仕様の参考資料として扱う |
| C | 権限 section 区分 | **admin / form / mypage の3区分** | 設計意図は §3 参照（誤配線防止・マトリクス見通し・代理店差はロール＋Punditで表現）。CEO意図確認済み |
| D | モデル命名 | **`jasmin_` プレフィックスを外す**（Customer, Order, Store…） | 新規サービス名称（プロダクト名）は未定。名称確定後も内部モデル名は汎用名を維持 |
| E | 移植の起点 | **rails new + ftlogから選択移植** | ftlog複製はテナント機構・issue系の削除コストが高いため不採用 |
| F | データ移行スコープ | **別フェーズ切り出し** | legacy-research/ETL設計は流用。スキーマ設計時にマッピング整合を常時確認 |

---

## 8-2. R0/R2着手前ブロッカーのCTO自律決定（2026-08-15・CEO不在のため質問せず決定。事後修正歓迎）

2026-08-15の洗い直しレビュー（review-03参照）でR0/R2着手のブロッカーと判定された3論点を、CEO不在の制約下でCTO判断により決定し実装を進める。いずれも根拠を明記し、誤りがあればCEO確認後に訂正する。

| # | 論点 | CTO決定 | 根拠 |
|---|---|---|---|
| D-補足 | JasminCustomer→Customerのリネーム衝突 | **決定Dの通りCustomerで進める**（再分割はしない） | `01-laravel-current-analysis.md`§2-2で実コード確認済み: `JasminCustomer`は既に`Authenticatable`＋`customer`ガードでマイページログイン主体を兼ねている。Inquiry-email.mdの分離懸念は「契約とログインを分けるべき」という将来TODOであり、現在の実装は既に統合済みの姿。決定D（CEO決定2026-08-14）は実態と矛盾しない。T-4（命名の曖昧さ）は「別モデルに分割すべきだったのに分割していない」という設計負債として認識し、R2完了後にCEOへ再分割要否を提案する形で持ち越す |
| Q-23 | 全画面2要素認証（マイページ・受注入力） | **マイページ=Devise Customerスコープに同型メールOTPを追加。受注入力（form）=独自セッション内に同じOTP機構（メール送信→コード照合）を追加ステップとして組み込む** | development-plan.md Q-23（D-5・CEO決定2026-07-26）「全画面必須」に準拠。実装方式はR0のメールOTP実装（User向け）を横展開する形でR3のform認証・R4のmypage認証に組み込む |
| 認可統合 | formセクションのRBAC統合方式 | **(b) 採用: form名前空間は`authorize_system_permission!`を完全スキップし、独自FormAuthミドルウェアのみで保護** | SalesRepresentativeはDevise対象外（03§4）でSTI判定（`user.staff?`/`customer?`）に乗らないため、(a)のchecker拡張は不自然な特別分岐を増やす。(b)はftlogの`skip_system_permission_authorization?`と同じパターンを踏襲でき、責務分離も明快 |

---

## 9. 参照

- 01-laravel-current-analysis.md（現行Laravel分析）
- 02-ftlog-architecture-analysis.md（ftlog解剖・RBAC詳細）
- 04-implementation-plan.md（実装計画）
- Laravel側要件: `projects/boilerplate-vue-env/laravel/requirements/`（basic-design.md ほか）
