# カラム設計書

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/Column.md）を brige-crm（Rails 8.1）の現行実装（`db/schema.rb` version 2026_08_16_150002・`app/models/*.rb`）と 03/04 の決定に合わせて全面見直し。フェーズ対応: §1〜§11 = R1/R2 実装済み（一部 R3/R4 で列追加）、§12 = R0〜R4 で追加された実装済みテーブル、§13 = 未実装（R5/R6）。突合結果は末尾「§14 実装突合表（2026-08-19）」参照。
> 最終更新: 2026-08-19（Rails版突合。旧: 2026-05-22 products / plans / agency_products 追加）
> ステータス: 実装突合済み。**以後、スキーマの正は `db/schema.rb`**（本書は設計意図・業務要件・実データ根拠を保持する設計書として `schema.rb` に追従させる）

---

## 目次

0. [Rails版 共通規約（全テーブル共通）](#0-rails版-共通規約全テーブル共通)
1. [agency_groups（代理店グループ）](#1-agency_groups代理店グループ)
2. [agencies（代理店）](#2-agencies代理店)
3. [products（商材）](#3-products商材)
4. [plans（プラン）](#4-plansプラン)
5. [agency_products（代理店-商材許可）](#5-agency_products代理店-商材許可)
6. [contract_conditions（契約条件）](#6-contract_conditions契約条件)
7. [sales_representatives（営業担当者）](#7-sales_representatives営業担当者)
8. [customers（顧客。旧 jasmin_customers）](#8-customers顧客旧-jasmin_customers)
9. [stores（店舗。旧 jasmin_stores）](#9-stores店舗旧-jasmin_stores)
10. [orders（案件。旧 jasmin_orders）](#10-orders案件旧-jasmin_orders)
11. [order_work_details（案件作業詳細。旧 jasmin_order_work_details）](#11-order_work_details案件作業詳細旧-jasmin_order_work_details)
12. [R0〜R4 で追加された実装済みテーブル](#12-r0r4-で追加された実装済みテーブル)
13. [未実装テーブル（R5/R6）](#13-未実装テーブルr5r6)
14. [実装突合表（2026-08-19）](#14-実装突合表2026-08-19)

---

## 凡例

| 記号 | 意味 |
|---|---|
| PK | 主キー |
| FK | 外部キー |
| UQ | ユニーク制約（unique index） |
| IDX | インデックス |
| NOT NULL | NULL不可 |
| NULL | NULL許可 |
| ENC | ActiveRecord::Encryption による暗号化カラム（`encrypts`。deterministic: false） |

**型表記（Rails版）**: 本書の型は Rails マイグレーション型で表記する（PostgreSQL 16 上の実体型を括弧内に示す）。
`uuid`（uuid）/ `string`（character varying。`string(n)` は `limit: n`）/ `text`（text）/ `integer`（integer）/ `bigint`（bigint）/ `boolean`（boolean）/ `date`（date）/ `datetime`（timestamp(6) without time zone）/ `jsonb`（jsonb）/ `string[]`（character varying[]）。
旧Laravel設計の `UNSIGNED INT/SMALLINT/TINYINT` は実装ではすべて `integer`（範囲チェックはモデルの `numericality` バリデーション）、`ENUM` は `string` ＋ モデルの `inclusion` バリデーションに読み替えている。

---

## 0. Rails版 共通規約（全テーブル共通）

`db/schema.rb`・`app/models` の実装に基づく、全テーブル共通の規約。各テーブルの節では繰り返さない。

| 項目 | 実装 |
|---|---|
| 主キー | 全テーブル `id uuid`、`default: gen_random_uuid()`（`config.generators.orm :active_record, primary_key_type: :uuid`） |
| タイムスタンプ | `created_at` / `updated_at`（datetime, **NOT NULL**。Rails `timestamps`）。旧設計は NULL 許可だったが実装は NOT NULL |
| 作成者・更新者 | `created_by_id` / `updated_by_id`（uuid, NULL, FK → users.id）。旧設計名 `created_by` / `updated_by` から Rails 規約で `_id` 付きに変更。`TracksUser` concern（`app/models/concerns/tracks_user.rb`）が `Current.user` から自動設定する。中間テーブル・ログ系・カウンタ・active_storage_* には持たない |
| 外部キー | `add_foreign_key` で DB 制約を張る。`on_delete` は各節に記載（restrict / cascade / nullify）。無指定は既定（restrict 相当） |
| ステータス列 | `customers.status` / `orders.status` / `inquiries.status` は文字列でマスタ（`customer_statuses` / `order_statuses` / `inquiry_statuses`）の `code` を格納。**DB FK は張らず**モデルの `validate :status_must_exist_in_*` でマスタ行の存在を検証（運用中に権限管理UIから集合を追加できるようにするため。`is_system=true` 行はコードから参照するため削除・code変更禁止 = `SystemManagedStatus` concern） |
| 採番 | `customer_number` / `order_number` / `inquiry_number` は `sequence_counters`（§12-5）を `SequenceCounter.next_value!(key)`（PostgreSQL の単一 `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` でアトミック）で払い出す。旧Laravelの `count()+1` / `whereYear()->count()+1` 方式（同時作成で重複しうる T-1 系脆弱性）は**採用しない** |
| PII暗号化 | `pii-handling-rules.md` §1 分類B（外部認証情報）を ActiveRecord::Encryption（`encrypts`, 非決定的）で暗号化。対象は `orders.billing_password` と `order_work_details` の8列（§11）。暗号化後は平文より長くなるため列型は `text`。分類A（顧客の氏名・電話・メール等）は暗号化しない（04 R2 レビュー: 決定記録の明文化が未了 → 要確認） |
| 監査ログ | `Auditable` concern の `TRACKED_FIELDS`（`app/models/concerns/auditable.rb`）に列挙した列の変更差分のみ `audit_logs`（§12-3）へ記録。暗号化列・本文系は含めない |
| 認証列 | 管理画面ユーザー `users`（Devise: database_authenticatable / recoverable / lockable / timeoutable）、顧客マイページ `customers`（Devise: database_authenticatable / lockable / timeoutable。recoverable なし）、受注入力 `sales_representatives`（Devise 対象外。代理店CD＋営業担当者CD で本人特定）。3者とも `OtpAuthenticatable` concern のメールOTP列（`otp_code_digest` / `otp_code_expires_at` / `otp_attempts`。10分・5回）を持つ |
| ポリモーフィック | `*_recipients` / `system_notifications` / `recipient_group_members` の `recipient_type` + `recipient_id` は Rails polymorphic 規約（`recipient_type` はクラス名文字列。許可クラスはモデル定数で制限。DB FK なし） |
| 命名 | 決定D（03§8-2）: `jasmin_` プレフィックスを除去し `Customer` / `Store` / `Order` / `OrderWorkDetail`。テーブル名は Rails 複数形。旧名は各節見出しに併記 |

---

## 1. agency_groups（代理店グループ）

**モデル名:** `AgencyGroup`（`app/models/agency_group.rb`）
**テーブル名:** `agency_groups`
**実装状況:** 実装済み（R1。P1 相当）
**用途:** 代理店グループを管理するテーブル。グループ固有の属性（グループ名・サービス種別・グループCD・連絡先メール・Bridgeプラン表示区分・CSVダウンロード表示フラグ）を保持し、傘下の `agencies` を束ねる基点となる。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `agencies` | hasMany | `agency_group_id = agency_groups.id`（`dependent: :restrict_with_error`。FK on_delete: restrict） |
| `users` | hasMany | グループアカウント（`agency_group_id` 経由。`dependent: :restrict_with_error`） |
| `agency_group_products` / `products` | hasMany / hasMany through | 販売許可商材（§12-1-4。旧設計に無かった Product×AgencyGroup 中間。R2 追加） |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `name` | string | NOT NULL | - | IDX | グループ名称（例: 株式会社EdgeConnect） |
| `service_type` | string | NOT NULL | - | - | サービス種別：`Bridge` / `BridgePlus`（`AgencyGroup::SERVICE_TYPES` で inclusion 検証。旧設計の IDX は実装では未作成） |
| `group_code` | string | NOT NULL | - | UQ | グループCD（例: 971201 / 52313510）。ログインIDと常に同値。固定・不変 |
| `contact_email` | string | NULL | - | - | グループ連絡先メールアドレス（Bridge: グループアカウントメールアドレス / BridgePlus: 担当メールアドレス。同一概念） |
| `bridge_plan_display_type` | string | NULL | - | - | #Bridgeプラン表示区分。値: `ハイブリッド` / `プラン全表示` / `ストック`（旧設計 ENUM → string ＋ inclusion 検証。`ストック` は本番CSV由来の実データに存在するため追加） |
| `csv_download_visible` | boolean | NULL | - | - | CSVダウンロードボタン表示フラグ（**Bridge側のみ**。BridgePlus側グループはNULL） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

> 実装との差分: 共通差分（§0）のほか、`service_type` のインデックスが未作成（要否は運用で判断）。それ以外は一致。

### グループアカウント（users テーブル）との関係

グループには管理画面ログイン用のユーザアカウントが1件紐づく（1グループ = 1アカウント）。

| 画面表示項目 | 対応カラム | 備考 |
|---|---|---|
| ログインID（UI表示） | `agency_groups.group_code` | 業務上のグループCD。UI上の「ログインID」として表示するが、実際の認証は users.email で行う |
| グループアカウントメールアドレス | `users.email` | `agency_groups.contact_email` と同値になる |
| 営業担当者（氏名） | `users.name` | このグループアカウントのログインを担当する特定の営業担当者名（1名固定） |

> `contact_email`（agency_groups）と `users.email` は同一の値を持つ。更新時は両方を同期する必要がある。

### 実データ（BridgePlus側グループ 全6件）

| group_code | name | contact_email | bridge_plan_display_type | csv_download_visible |
|---|---|---|---|---|
| 971201 | 株式会社EdgeConnect | （未設定） | ハイブリッド | NULL |
| 52313510 | 株式会社Meta Sales(取次) | （未設定） | ハイブリッド | NULL |
| 52314510 | 株式会社壱(取次) | （未設定） | ハイブリッド | NULL |
| 52315800 | 株式会社Bond | （未設定） | ハイブリッド | NULL |
| 52315700 | 株式会社グライナー | （未設定） | ハイブリッド | NULL |
| 52315600 | 株式会社KGpartners | （未設定） | ハイブリッド | NULL |

### 実データ（Bridge側グループ 確認分）

| group_code | name | contact_email | bridge_plan_display_type | csv_download_visible |
|---|---|---|---|---|
| 11111111 | テストグループ | test@reclick.co.jp | プラン全表示 | false（非表示） |

### 備考

- `group_code` は業務上のグループCDであり、変更不可。UI上の「ログインID」表示項目として使用するが、実際の認証は users.email で行う
- `bridge_plan_display_type` の確定値: `ハイブリッド` / `プラン全表示` / `ストック` の3種類（当初2種類としていたが、本番CSV由来の実データ移植（db/seeds/agency_groups.rb）で `ストック` 8件を確認したため追加）
- `csv_download_visible` はBridge側のみ使用。BridgePlus側グループは常にNULL
- `contact_email` はBridgePlus側では全件未設定（空）、Bridge側ではアカウントメールと同値

---

## 2. agencies（代理店）

**モデル名:** `Agency`（`app/models/agency.rb`）
**テーブル名:** `agencies`
**実装状況:** 実装済み（R1）
**用途:** 代理店を管理するテーブル。業務上の代理店CDを保持し、契約条件・営業担当者・顧客・案件との紐づけ基点となる。各代理店は `agency_group_id` で代理店グループに所属する。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `agency_groups` | belongsTo | `agency_group_id = agency_groups.id`（FK on_delete: restrict） |
| `products` | has_many through | `agency_products` 経由（販売許可商材。`Product.sellable_by` で参照） |
| `contract_conditions` | hasMany | 全バージョン（`dependent: :destroy`。FK on_delete: cascade） |
| `contract_conditions` | hasOne（相当） | `effective_until IS NULL`（現行バージョンのみ。実装は `Agency#current_contract_condition` 系のスコープ） |
| `sales_representatives` | hasMany | `agency_id` 経由（`restrict_with_error`） |
| `users` | hasMany | 代理店アカウント（`agency_id` 経由。`restrict_with_error`。FK on_delete: restrict） |
| `customers` | hasMany | `agency_id` 経由（`restrict_with_error`） |
| `orders` | hasMany | `agency_id` 経由（`restrict_with_error`） |
| `applications` | hasMany | 申込トランザクション（§12-6-4。R3） |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `agency_group_id` | uuid | NOT NULL | - | FK, IDX | 所属グループ（agency_groups.id） |
| `name` | string | NOT NULL | - | IDX | 代理店名称（例: 株式会社Meta Sales(取次)） |
| `agency_code` | string | NOT NULL | - | UQ | 代理店CD（契約条件が変更されても不変の固定識別子）。UI上の「ログインID」表示項目として使用するが、実際の認証は users.email で行う |
| `contact_person` | string | NULL | - | - | 店所担当者名（Bridge: アカウント情報「担当者」/ BridgePlus: 代理店情報「店所担当者」。同一概念） |
| `email_1` | string | NULL | - | - | 通知先メールアドレス1（主担当） |
| `email_2` | string | NULL | - | - | 通知先メールアドレス2 |
| `email_3` | string | NULL | - | - | 通知先メールアドレス3 |
| `email_4` | string | NULL | - | - | 通知先メールアドレス4 |
| `email_5` | string | NULL | - | - | 通知先メールアドレス5 |
| `electronic_contract_enabled` | boolean | NULL | - | - | 電子契約フラグ（**Bridge側のみ**。true=利用可能 / false=利用不可。BridgePlus側はNULL） |
| `csv_download_visible` | boolean | NULL | - | - | CSVダウンロードボタン表示フラグ（**Bridge側のみ**。BridgePlus側はNULL） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

> 実装との差分なし（列・制約とも一致。`agency_code` UQ / `name` IDX / `agency_group_id` IDX）。

### 代理店アカウント（users テーブル）との関係

代理店には管理画面ログイン用のユーザアカウントが1件紐づく（1代理店 = 1アカウント）。Bridge・BridgePlus両方の代理店に必要。

| 画面表示項目 | 対応カラム | 備考 |
|---|---|---|
| ログインID | `agencies.agency_code` | 代理店CDと常に同値 |
| 代理店アカウントメールアドレス | `users.email` | ログイン用メールアドレス |
| 担当者（氏名） | `users.name` | = `agencies.contact_person` と同概念 |

**権限・アクセス制御の方針（実装済み: Pundit `AgencyScoped` concern・`app/policies/concerns/agency_scoped.rb`）**

- 代理店アカウントは組み込みロール `代理店用`、代理店グループアカウントは `代理店グループ用`（`SystemRole::BUILT_IN_ROLE_ATTRIBUTES`。§12-2-2）
- 管理画面のレコード表示は `policy_scope` で制御: ログインユーザの `users.agency_id` が `orders.agency_id`（customers / stores / sales_representatives も同様）と一致する場合のみ
- 代理店グループアカウントは `users.agency_group_id` に紐づく全 `agencies.id` の案件を参照可能（`agencies WHERE agency_group_id = ?` で傘下代理店ID一覧を取得）
- `users.agency_group_id` と `users.agency_id` の両方 NULL = 社内（admin / 実務運用者）で全件アクセス。両方同時設定は `User#agency_scope_is_exclusive` で禁止

> **確定（⑥）**: 代理店・代理店グループのログインは `users` テーブルで一元管理する。`agency_code` / `group_code` は業務上の識別子であり、UI表示用の「ログインID」概念として使用する。実際の認証は `users.email`（メールアドレス）＋パスワードで行う。別途 `login_id` カラムは追加しない。

> **確定**: 代理店ログイン用メールアドレスは `users.email` を使用する。`email_1`〜`email_5` は通知先メールアドレス専用であり、ログイン認証とは別管理とする。

### 実データ（BridgePlus代理店 全13件）

| agency_code | name | contact_person | email_1 | email_2 | email_3 | electronic_contract_enabled | csv_download_visible |
|---|---|---|---|---|---|---|---|
| 52313510 | 株式会社Meta Sales(取次) | - | takuya.ohori.web@gmail.com | yamashita_shingo@ftgroup.co.jp | - | NULL | NULL |
| 52314510 | 株式会社壱（取次） | - | m.taguchi@i-chi.co.jp | yamashita_shingo@ftgroup.co.jp | - | NULL | NULL |
| 52315800 | 株式会社Bond | - | info@go-bond.jp | yamashita_shingo@ftgroup.co.jp | - | NULL | NULL |
| 52315700 | 株式会社グライナー | - | y_tsubouchi@greiner.co.jp | yamashita_shingo@ftgroup.co.jp | - | NULL | NULL |
| 52315600 | 株式会社KGpartners | - | bridgeplus_tokyo@edgeconnect.co.jp | k.jimbo@to-lead.jp | yamashita_shingo@ftgroup.co.jp | NULL | NULL |
| 52315500 | 株式会社オーシャン | - | oceanmake97@gmail.com | yamashita_shingo@ftgroup.co.jp | - | NULL | NULL |
| 52314700 | 十倉商店合同会社 | - | bridgeplus_tokyo@edgeconnect.co.jp | tokura@tokurashouten.net | yamashita_shingo@ftgroup.co.jp | NULL | NULL |
| 52314600 | HIKIYOSE株式会社 | - | info@hikiyose.tech | yamashita_shingo@ftgroup.co.jp | - | NULL | NULL |
| 52314500 | 株式会社壱 | - | ichi.kengen@gmail.com | yamashita_shingo@ftgroup.co.jp | - | NULL | NULL |
| 52314400 | 株式会社ワーディ | - | h.inoue@worddy.jp | m.masuda@worddy.jp | yamashita_shingo@ftgroup.co.jp | NULL | NULL |
| 52314200 | 株式会社バリューコミュニケーションズ | - | yamashita_shingo@ftgroup.co.jp | - | - | NULL | NULL |
| 52314100 | 株式会社セレブリックス | - | yamashita_shingo@ftgroup.co.jp | - | - | NULL | NULL |
| 52314000 | 株式会社ストロングジャパンホールディングス | - | yamashita_shingo@ftgroup.co.jp | - | - | NULL | NULL |

> ※ オーシャン・十倉商店等8社はソースデータ上グループCDが代理店CDと同値だが、新システムでは 971201 EdgeConnect 配下として管理する（グループ兼代理店の設計課題参照）

### 実データ（Bridge代理店 確認分）

| agency_code | name | contact_person | email_1 | electronic_contract_enabled | csv_download_visible |
|---|---|---|---|---|---|
| 123456 | 運用管理部(テスト) | - | minegishi_toshikazu@ftgroup.co.jp | true（利用可能） | false（非表示） |

### 備考

- `agency_code` は業務上の代理店CDであり、変更不可。UI上の「ログインID」表示項目として使用するが、実際の認証は users.email で行う
- `contact_person` は店所担当者名（Bridge: 担当者 / BridgePlus: 店所担当者。同一概念。任意入力）
- `email_1`〜`email_5` は申込・ステータス変更等の通知送付先。現データでは最大3件使用、4・5は常にNULL
- 通知先メールは将来的に別テーブル（`agency_emails`）へ切り出す可能性あり（現時点は固定カラム運用）
- `electronic_contract_enabled` はBridge側のみ使用。BridgePlus側はNULL
- `csv_download_visible` はBridge側のみ使用。BridgePlus側はNULL

### ⚠️ 設計課題：グループ兼代理店（BridgePlus）

Meta Sales（52313510）・壱取次（52314510）・Bond（52315800）・グライナー（52315700）・KGpartners（52315600）の5社は、グループ一覧と代理店一覧の**両方に同一CDで登場**する。

```
ソースデータ上の構造:
  グループCD 52313510 = 代理店CD 52313510（株式会社Meta Sales）
  → グループとしても、代理店としても登録されている
```

新システムでの表現方法：`agency_groups` と `agencies` を別テーブルで管理する構造上、グループ兼代理店の5社は `agency_groups` レコードに加えて `agencies` レコード（`agency_group_id` で自グループを参照）を持つ形で登録する。

> **確定方針:** 1つの `agency_groups` レコードに対して、傘下の `agencies` レコードを持てる構造をそのまま活用。グループ兼代理店も `agencies` レコードを1件作成し、`agency_group_id` で自グループに紐づける。

---

## 3. products（商材）

**モデル名:** `Product`（`app/models/product.rb`）
**テーブル名:** `products`
**実装状況:** 実装済み（R2 タスク3）
**用途:** 販売可能な商材を管理するマスターテーブル。各商材には複数のプランが紐づく。代理店ごとに販売許可する商材を `agency_products` テーブルで管理する。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `plans` | hasMany | `product_id = products.id`（`restrict_with_error`。FK on_delete: restrict） |
| `product_initial_fees` | hasMany | 初期費用テンプレート（§12-1-1。`dependent: :destroy`） |
| `product_options` | hasMany | オプション（§12-1-2。`dependent: :destroy`） |
| `agencies` | has_many through | `agency_products` 経由（販売許可代理店） |
| `agency_groups` | has_many through | `agency_group_products` 経由（§12-1-4） |
| `form_template` | hasOne | 申込フォーム定義（§12-6-1。商材と 1:1、`form_templates.product_id` UQ） |
| `applications` | hasMany | 申込トランザクション（§12-6-4。`restrict_with_error`） |
| `orders` | has_many through | `plans` 経由 |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `name` | string(100) | NOT NULL | - | - | 商材名（例: BridgePlus / Bridge） |
| `code` | string(20) | NOT NULL | - | UQ | 商材コード（例: BRIDGEPLUS / BRIDGE） |
| `description` | text | NULL | - | - | 商材説明 |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

> 実装との差分なし（列・制約とも一致）。

---

## 4. plans（プラン）

**モデル名:** `Plan`（`app/models/plan.rb`）
**テーブル名:** `plans`
**実装状況:** 実装済み（R2 タスク3）。**実装が設計と異なる（列構成）**: 旧設計でプランに持たせていた初期費用・支払方法・契約単位・初期構築・Plus情報は、実装では以下に分解された。
- 初期費用 → `product_initial_fees`（§12-1-1。商材配下の初期費用テンプレート。案件は `orders.product_initial_fee_id` で選択値を参照）
- 支払方法 → `orders.payment_method`（§10。案件ごとの入力値）
- Plusオプション等 → `product_options`（§12-1-2）＋ `order_options`（§12-1-3。案件⇄オプション中間）
- 契約単位 `contract_unit` / 初期構築 `initial_construction` → **実装なし**（要確認: 業務上必要なら R5 契約フローで追加）
**用途:** 商材ごとのプランを管理するマスターテーブル。月額料金等のプラン属性を保持する。案件（`orders`）は `plan_id` でプランを参照する。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `products` | belongsTo | `product_id = products.id`（FK on_delete: restrict） |
| `orders` | hasMany | `plan_id = plans.id`（`restrict_with_error`。FK on_delete: nullify） |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `product_id` | uuid | NOT NULL | - | FK, IDX | 商材（products.id） |
| `name` | string(100) | NOT NULL | - | - | プラン名（例: スタンダード（C）/ スタンダード（E）） |
| `code` | string(20) | NULL | - | - | プランコード |
| `monthly_fee` | integer | NULL | - | - | 月額料金（円。例: 29800。`numericality >= 0`） |
| `sort_order` | integer | NOT NULL | 0 | - | 表示順（実装で追加。`Plan.ordered` スコープ） |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ |
| ~~`initial_fee`~~ | integer | - | - | - | **実装なし** → `product_initial_fees.amount`（§12-1-1）へ移設 |
| ~~`payment_method`~~ | string(30) | - | - | - | **実装なし** → `orders.payment_method`（string(50)。§10）へ移設 |
| ~~`contract_unit`~~ | string(20) | - | - | - | **実装なし**（要確認。R5 契約フローで要否判断） |
| ~~`initial_construction`~~ | string(10) | - | - | - | **実装なし**（要確認。R5 契約フローで要否判断） |
| ~~`plus_flag`~~ | string(20) | - | - | - | **実装なし** → `product_options` / `order_options`（§12-1-2, §12-1-3）で表現 |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

---

## 5. agency_products（代理店-商材許可）

**モデル名:** `AgencyProduct`（`app/models/agency_product.rb`）
**テーブル名:** `agency_products`
**実装状況:** 実装済み（R2 タスク3。モデル・クエリ `Product.sellable_by` のみ。**管理画面から許可を付与/剥奪する UI は未実装** = 04 R2 追加タスク）。**実装が設計と異なる**: 複合主キーではなく Rails 規約どおり `id uuid` 主キー＋ `(agency_id, product_id)` unique index ＋ `timestamps`。
**用途:** 代理店が販売を許可されている商材を管理する中間テーブル。A代理店はBridgePlusのみ、B代理店はBridgeのみ、等の販売許可を管理する。グループ単位の許可は `agency_group_products`（§12-1-4）。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `agencies` | belongsTo | `agency_id = agencies.id` |
| `products` | belongsTo | `product_id = products.id` |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（実装で追加） |
| `agency_id` | uuid | NOT NULL | - | FK, UQ（複合） | 代理店（agencies.id）。FK on_delete: cascade |
| `product_id` | uuid | NOT NULL | - | FK, UQ（複合）, IDX | 商材（products.id）。FK on_delete: cascade |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |

> unique index `index_agency_products_on_agency_id_and_product_id (agency_id, product_id)` で一意性を保証する（旧設計の複合PKを置き換え）。`created_by_id` / `updated_by_id` は持たない。

---

## 6. contract_conditions（契約条件）

**モデル名:** `ContractCondition`（`app/models/contract_condition.rb`）
**テーブル名:** `contract_conditions`
**実装状況:** 実装済み（R1）。列は設計どおり。**参照側は T-3 是正で `orders.contract_condition_id`（NOT NULL）に一本化**（旧Laravelは `customers` 側に持っていた。§8・§10 参照）
**用途:** 代理店に紐づく契約条件をバージョン管理するテーブル。契約条件が変更される際は新規レコードとして追加し、旧バージョンの `effective_until` に終了日を設定する。現行バージョンは `effective_until = NULL` で識別する。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `agencies` | belongsTo | `agency_id = agencies.id`（FK on_delete: cascade） |
| `orders` | hasMany | `orders.contract_condition_id`（受注時点のバージョンを固定参照。FK on_delete: restrict） |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `agency_id` | uuid | NOT NULL | - | FK, IDX | agencies.id への参照（on_delete: cascade） |
| `name` | string | NOT NULL | - | - | 契約条件名（BridgePlus案件一覧のグループ名に相当。例: 株式会社壱（取次）） |
| `effective_from` | date | NOT NULL | - | - | 適用開始日 |
| `effective_until` | date | NULL | - | IDX | 適用終了日（NULL = 現行バージョン） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

> 実装との差分なし（列・制約とも一致）。「現行バージョン」の取得は `effective_until IS NULL` スコープ。

### バージョン管理のイメージ

```
agencies.id = X（代理店CD: AGY-001）
  ├── contract_conditions.id = A
  │     name: "スタンダードプラン"
  │     effective_from: 2024-01-01
  │     effective_until: 2024-12-31  ← 旧バージョン（過去受注はここに紐づいたまま）
  └── contract_conditions.id = B
        name: "スタンダードプラン v2"
        effective_from: 2025-01-01
        effective_until: NULL         ← 現行バージョン（新規受注はここに紐づく）
```

---

## 7. sales_representatives（営業担当者）

**モデル名:** `SalesRepresentative`（`app/models/sales_representative.rb`）
**テーブル名:** `sales_representatives`
**実装状況:** 実装済み（R1。R3 で受注入力ログイン用のメールOTP列 `email` / `otp_*` を追加）。**実装が設計と異なる**: `sales_rep_code` / `name` / `pdf_*` に長さ制限（VARCHAR(50)/(100)）が無い（`string` 無制限。モデル側 length 検証も無し → 要確認・軽微）。
**用途:** 代理店に所属する営業担当者を管理するテーブル。受注入力画面（`Form::SessionsController`）のログイン認証（「代理店CD ＋ 営業担当者CD」で本人特定 → `email` 宛メールOTP。Q-23・D-5「全画面2要素認証」）にも使用する。Devise 対象外。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `agencies` | belongsTo | `agency_id = agencies.id`（FK on_delete: restrict） |
| `customers` | hasMany | `customers.sales_representative_id`（`dependent: :nullify`） |
| `orders` | hasMany | `orders.sales_representative_id`（`dependent: :nullify`） |
| `applications` | hasMany | 申込トランザクション（§12-6-4。`restrict_with_error`） |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `agency_id` | uuid | NOT NULL | - | FK, IDX | 所属代理店（agencies.id） |
| `sales_rep_code` | string | NOT NULL | - | **UQ（グローバル）** | 営業担当者CD。システム全体でユニーク（例: 980293〜980324）。旧設計 VARCHAR(50)、実装は無制限 |
| `name` | string | NOT NULL | - | - | 氏名。旧設計 VARCHAR(100)、実装は無制限 |
| `email` | string | NULL | - | IDX | 受注入力ログインのメールOTP送信先（R3 で追加。`Form::OtpsController`） |
| `otp_code_digest` | string | NULL | - | - | メールOTPのダイジェスト（`OtpAuthenticatable`。R3 で追加） |
| `otp_code_expires_at` | datetime | NULL | - | - | OTP有効期限（発行から10分。R3 で追加） |
| `otp_attempts` | integer | NOT NULL | 0 | - | OTP照合失敗回数（5回でロック。R3 で追加） |
| `pdf_store_name` | string | NULL | - | - | PDF出力用店所名。契約書PDF等に印刷する所属店舗・営業所名（例: 株式会社EdgeConnect(大阪営業所)） |
| `pdf_postal_code` | string | NULL | - | - | PDF出力用郵便番号（例: 330-0844）。**Bridge側のみ** |
| `pdf_prefecture` | string | NULL | - | - | PDF出力用都道府県（例: 埼玉県）。**Bridge側のみ** |
| `pdf_city` | string | NULL | - | - | PDF出力用市区郡（例: さいたま市大宮区）。**Bridge側のみ** |
| `pdf_town` | string | NULL | - | - | PDF出力用町名（例: 下町）。**Bridge側のみ** |
| `pdf_address_detail` | string | NULL | - | - | PDF出力用番地・ビル・建物（例: 2丁目16-1 ACROSSビル6F）。**Bridge側のみ** |
| `pdf_phone_number` | string | NULL | - | - | PDF出力用電話番号（例: 0800-700-6660）。**Bridge側のみ** |
| `pdf_fax_number` | string | NULL | - | - | PDF出力用FAX番号。**Bridge側のみ** |
| `is_active` | boolean | NOT NULL | TRUE | IDX | 有効フラグ（false = 無効化済み、ログイン不可） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

### ユニーク制約

- `sales_rep_code` の**グローバルユニーク制約**（システム全体で一意）。**T-2 是正済み**: Laravel現行も既にグローバルユニークだったためそのまま踏襲（代理店内ユニークではない。`index_sales_representatives_on_sales_rep_code` UNIQUE）

> ⚠️ 旧メモ（Laravel）: SampleDataSeeder のダミーコード（001, 002...）を実際のコード体系（6桁数値）に合わせる件 → Rails 版では `db/seeds.rb` / FactoryBot（`spec/factories`）の営業担当者コードを 6 桁数値体系に揃えること（要確認・R7 データ移行時の実コード投入と併せて）。

### 実データ（BridgePlus営業担当者 確認分 26件）

| sales_rep_code | name | pdf_store_name |
|---|---|---|
| 980324 | 大堀 拓哉 | 株式会社Meta Sales（取次） |
| 980323 | 井上 偉月 | 株式会社壱 |
| 980322 | 冨田 佳鈴 | 株式会社壱 |
| 980321 | 松井 伸太郎 | 株式会社壱 |
| 980320 | 佐々木 公生 | 株式会社壱 |
| 980319 | 田口 元紀 | 株式会社壱 |
| 980318 | 芝 萌香 | 株式会社ワーディ |
| 980316 | 荻山 瞳 | 株式会社ワーディ |
| 980314 | 古賀 温野 | 株式会社EdgeConnect(大阪営業所) |
| 980313 | 野勢 真亜利 | 株式会社EdgeConnect(大阪営業所) |
| 980312 | 酒井 大志 | 株式会社ワーディ |
| 980311 | 澤井 星輝 | 株式会社Bond |
| 980310 | 太田 哲平 | 株式会社グライナー |
| 980309 | 真弓 誠基 | 株式会社グライナー |
| 980308 | 幸田 信一 | 株式会社グライナー |
| 980307 | 谷口 美香 | 株式会社グライナー |
| 980306 | 坪内 祐矢 | 株式会社グライナー |
| 980305 | 御園 貴徳 | NULL |
| 980304 | 村田 元貴 | 株式会社ワーディ |
| 980303 | 山城 雪乃 | 株式会社EdgeConnect(大阪営業所) |
| 980302 | 萩原 和紀 | 株式会社EdgeConnect（東京営業所） |
| 980301 | 山田 純平 | 株式会社サポータス・システム・ソリューションズ |
| 980300 | 丸山 寛人 | 株式会社サポータス・システム・ソリューションズ |
| 980299 | 金田圭生 | 株式会社EdgeConnect(大阪営業所) |
| 980298 | 井上 詩穂 | 株式会社EdgeConnect（東京営業所） |
| 980293 | 十倉 寛治 | 十倉商店合同会社 |

> ※ 980294〜980297・980315・980317 は欠番（削除済みまたは未使用）
> ※ EdgeConnect（大阪・東京営業所）はテーブルには登録せず `pdf_store_name` の表示文字列として管理
> ※ 株式会社サポータス・システム・ソリューションズは今後追加予定の代理店

### 実データ（Bridge営業担当者 確認分）

| sales_rep_code | name | pdf_store_name | pdf_postal_code | pdf_prefecture | pdf_city | pdf_town | pdf_address_detail | pdf_phone_number | pdf_fax_number |
|---|---|---|---|---|---|---|---|---|---|
| 327028 | 白鳥 勇太 | エコテクソリューション株式会社 | 330-0844 | 埼玉県 | さいたま市大宮区 | 下町 | 2丁目16-1 ACROSSビル6F | 0800-700-6660 | NULL |

### 備考

- 受注入力画面のログインは「代理店CD（`agencies.agency_code`）＋ 営業担当者CD（`sales_rep_code`）」で本人を特定したうえで、`email` 宛のメールOTPを照合する2段階（実装済み: `Form::SessionsController` → `Form::OtpsController`）。`email` 未設定の担当者はOTPを受け取れないためログイン不可（運用上は必須項目扱い。要確認: DB 上は NULL 許可）
- `pdf_store_name` は代理店マスタとは独立した自由入力テキスト。NULL許可。契約書PDF出力自体は **R5 未実装**
- `pdf_postal_code`〜`pdf_fax_number` は**Bridge側のみ**。BridgePlus側は全カラムNULL
- `is_active = false` の担当者はログイン不可とする（実装済み。`index_sales_representatives_on_is_active`）
- 認証イベント（OTP発行/照合/失敗）は `AuditLog` に記録（`after_otp_event` を直接オーバーライド。`AuthAuditable` は Devise 前提のため include しない）

---

## 8. customers（顧客。旧 jasmin_customers）

**モデル名:** `Customer`（`app/models/customer.rb`。決定D により `JasminCustomer` → `Customer`）
**テーブル名:** `customers`（旧設計名 `jasmin_customers`）
**実装状況:** 実装済み（R2 タスク1。R4 タスク5 でマイページ認証用の Devise/OTP 列を追加）。実装との差分:
- `contract_condition_id` は **持たない**（T-3 是正: `orders.contract_condition_id` に一本化。§10）
- `phone_number` は実装名 **`phone`**（P2-4 / R-1 の読み替えを実装名として確定）
- Devise（database_authenticatable / lockable / timeoutable）＋メールOTP列を追加。`email` に **unique index** を追加（マイページ認証キー。PostgreSQL の unique index は NULL 複数可のため未設定顧客には影響なし。要確認: 同一メールの顧客を複数登録する業務がある場合は衝突する）
- `status` の既定値は `applied`（`customer_statuses.code`。旧設計の日本語ラベル `申込受付` は `customer_statuses.label`。§12-4-1）
- 呼称: `customer_statuses` は表示上「申込ステータス」へ統一予定（04 R2 追加タスク Q-B・status-naming-analysis.md 案A。ビュー側の統一は未完）
**用途:** BridgePlus・Bridgeサービスの顧客を管理するテーブル。契約者情報・連絡先・住所・請求書送付先・外部システム連携コードを保持する。BridgePlusとBridgeで画面表示項目がほぼ共通のため、同一テーブルで管理する（`customer_number` の prefix で判別可能）。顧客マイページ（`Mypage::*`）のログイン主体も兼ねる（03§4 決定D-補足）。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `agencies` | belongsTo | 所属代理店（`agency_id = agencies.id`。FK on_delete: restrict） |
| ~~`contract_conditions`~~ | ~~belongsTo~~ | **実装なし**（T-3 是正で `orders` 側へ移動） |
| `sales_representatives` | belongsTo | 担当営業担当者（nullable。FK on_delete: nullify） |
| `stores` | hasMany | 紐づく設置先店舗（`dependent: :destroy`） |
| `orders` | hasMany | 案件（`restrict_with_error`） |
| `applications` | hasMany（逆参照） | `applications.customer_id`（申込完了時に生成。§12-6-4） |
| `system_notifications` | hasMany（polymorphic recipient） | マイページ向けアプリ内通知（§12-8-4） |

### カラム一覧

#### 基本・管理情報

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `customer_number` | string(20) | NOT NULL | - | UQ | 顧客番号。BridgePlus: `FTWxxxxxxx` 形式 / Bridge: `JETxxxxxxx` 形式。旧システムの番号をそのまま格納（R7 移行）。新規作成時は `Customer#assign_customer_number` が `SequenceCounter.next_value!("customer_number")` で **`C-%06d`** 形式を自動採番（要確認: 旧 prefix `FTW`/`JET` を新規採番でも使うかは未決） |
| `name` | string(255) | NOT NULL | - | IDX | 契約者名または法人名 |
| `agency_id` | uuid | NOT NULL | - | FK, IDX | 所属代理店（agencies.id。on_delete: restrict） |
| ~~`contract_condition_id`~~ | uuid | - | - | - | **実装なし**（T-3 是正。受注時点の契約条件バージョンは `orders.contract_condition_id` NOT NULL で固定参照。§10） |
| `sales_representative_id` | uuid | NULL | - | FK, IDX | 担当営業担当者（sales_representatives.id）。削除時NULL化 |
| `status` | string(50) | NOT NULL | `applied` | IDX | ワークフローステータス。`customer_statuses.code` を格納（DB FK なし。`status_must_exist_in_customer_statuses` で検証）。既定集合（`StatusSeeder::CUSTOMER_STATUSES`）: applied=申込受付 / needs_correction=不備確認中 / returned=差戻し / confirm_call_pending=確認コール待ち / confirm_call_done=確認コール済 / needs_reconfirmation=再確認要 / contracted=契約確定 / withdrawn=退会済み（applied / withdrawn は is_system） |
| `applied_at` | date | NULL | - | IDX | お申込日 |
| `contracted_at` | date | NULL | - | - | 契約日 |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

#### マイページ認証（R4 タスク5 で追加。Devise + メールOTP）

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `encrypted_password` | string | NOT NULL | `""` | - | Devise database_authenticatable。R3 の申込経路ではパスワード無しで作成される（`:validatable` は入れない） |
| `failed_attempts` | integer | NOT NULL | 0 | - | Devise lockable（`maximum_attempts: 5`） |
| `unlock_token` | string | NULL | - | UQ | Devise lockable |
| `locked_at` | datetime | NULL | - | - | Devise lockable（`unlock_strategy: :time`） |
| `otp_code_digest` | string | NULL | - | - | メールOTPダイジェスト（`OtpAuthenticatable`） |
| `otp_code_expires_at` | datetime | NULL | - | - | OTP有効期限（10分） |
| `otp_attempts` | integer | NOT NULL | 0 | - | OTP失敗回数（5回でロック） |

> `email`（連絡先セクション）に unique index `index_customers_on_email` を追加済み（認証キー）。パスワード再設定UIは無い（旧 routes/mypage.php にも無いため `:recoverable` は対象外）。

#### 契約者基本情報

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `applicant_type` | string(20) | NULL | - | - | 申込者区分: `法人` / `個人事業主` / `個人` |
| `agency_customer_code` | string(50) | NULL | - | - | 代理店用顧客コード |
| `inventory_type` | string(50) | NULL | - | - | 在庫区分: `新規` / etc. |
| `contractor_name_kana` | string(255) | NULL | - | - | 契約者名または法人名カナ |

#### 法人代表者情報

> BridgePlusは姓/名分割（「大堀」「拓哉」）、Bridgeは氏名一括（「運用管理部テスト」）。本テーブルでは**一括格納に統一**。BridgePlusのデータはインポート時に「姓 名」として結合して格納する。

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `representative_name` | string(100) | NULL | 法人代表者名（氏名一括。例: 小笠原 勇人） |
| `representative_name_kana` | string(100) | NULL | 法人代表者名カナ（例: オガサワラ ハヤト） |

#### 担当者情報1

> BridgePlusは姓/名分割（「黒田」「尚樹」）、Bridgeは氏名一括（「運用管理部テスト」）。代表者名と同様に**一括格納に統一**。

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `contact_name` | string(100) | NULL | 担当者名（氏名一括。例: 黒田 尚樹） |
| `contact_name_kana` | string(100) | NULL | 担当者名カナ（例: クロダ ナオキ） |
| `contact_title` | string(50) | NULL | 担当者役職 |
| `contact_dept_phone` | string(20) | NULL | 担当部署電話番号 |

#### 担当者情報2

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `contact2_name` | string(100) | NULL | 担当者名_2（氏名一括） |
| `contact2_name_kana` | string(100) | NULL | 担当者名_2カナ |
| `contact2_title` | string(50) | NULL | 担当者役職_2 |
| `contact2_dept_phone` | string(20) | NULL | 担当部署電話番号_2 |

#### 契約者住所

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `postal_code` | string(8) | NULL | 郵便番号 |
| `prefecture` | string(20) | NULL | 都道府県 |
| `city` | string(50) | NULL | 市区郡 |
| `town` | string(100) | NULL | 町名 |
| `address_detail` | string(200) | NULL | 番地・ビル・建物名 |

#### 連絡先

> **実装注記（P2-4 / R-1 解決 → Rails 版で確定）**: 旧設計の `phone_number` は Rails 実装では **`phone`** という列名で作成した（Laravel 時代の既存列名を踏襲）。`mobile_phone` も実装済み。

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `phone` | string(20) | NULL | ご連絡先電話番号（旧設計名 `phone_number`） |
| `fax_number` | string(20) | NULL | ご連絡先FAX番号 |
| `mobile_phone` | string(20) | NULL | 携帯電話番号 |
| `mobile_contact_person` | string(50) | NULL | 携帯電話ご担当者 |
| `email` | string(255) | NULL | メールアドレス。**UQ**（`index_customers_on_email`。マイページ認証キー。R4 で追加） |

#### 業種・事業情報

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `industry` | string(50) | NULL | 業種 |
| `industry_sub` | string(50) | NULL | 業種（小区分） |
| `years_in_business` | string(20) | NULL | 営業年数。BridgePlusは数値文字列（「1」等）、Bridgeは選択肢文字列（「1年から5年」等）のため string(20) で統一 |
| `num_employees` | integer | NULL | 従業員数 |
| `num_offices` | integer | NULL | 営業所数 |

#### 請求書送付先情報

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `consolidated_billing` | boolean | NULL | 合算請求希望（true=希望する / false=希望しない） |
| `invoice_destination` | string(50) | NULL | 請求書送付先種別（`設置先住所と同一` / `契約者住所と同一` / etc.） |
| `invoice_name` | string(255) | NULL | 請求書送付先名 |
| `invoice_name_kana` | string(255) | NULL | 請求書送付先名カナ |
| `invoice_postal_code` | string(8) | NULL | 請求書送付先郵便番号 |
| `invoice_address` | string(500) | NULL | 請求書送付先ご住所（文字列） |
| `invoice_phone` | string(20) | NULL | 日中のご連絡先電話番号 |
| `invoice_other_phone` | string(20) | NULL | その他の電話番号 |

#### スタッフ・担当者コード

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `confirm_staff_code` | string(20) | NULL | 確認担当者コード |
| `confirm_staff_name` | string(50) | NULL | 確認担当者名 |
| `appointer_code` | string(20) | NULL | アポインター担当者コード |
| `appointer_name` | string(50) | NULL | アポインター担当者名 |

#### 外部システム連携

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `lbc_code` | string(20) | NULL | LBCコード |
| `sales_mgmt_customer_code` | string(20) | NULL | 販売管理S顧客CD |
| `netmove_member_id` | string(50) | NULL | ネットムーブ会員ID |
| `netmove_registered_at` | date | NULL | ネットムーブ登録日 |
| `sms_mobile_number` | string(20) | NULL | SMS送信用携帯番号 |

### BridgePlus / Bridge 差分対照表

| 項目 | BridgePlus | Bridge | 本テーブルの格納方針 |
|---|---|---|---|
| 顧客番号 prefix | `FTW` | `JET` | `customer_number` にそのまま格納 |
| 法人代表者名 | 姓/名/カナ姓/カナ名（4フィールド） | 氏名一括 + カナ一括（2フィールド） | 一括格納に統一（BridgePlusは結合して格納） |
| 担当者名 | 姓/名/カナ姓/カナ名（4フィールド×2セット） | 氏名一括+カナ一括（2フィールド×2セット） | 一括格納に統一 |
| 営業年数 | 数値文字列（「1」等） | 選択肢文字列（「1年から5年」等） | string(20) で統一 |
| 支払方法・カード情報 | 存在 | 存在 | 将来の orders/payments テーブルで管理予定 |

### 備考

- `name` は「契約者名または法人名」に相当。`contractor_name_kana` でカナを補完
- `representative_name` / `contact_name` は氏名一括格納（姓名スペース区切り）。BridgePlusのインポート時は「姓 名」に結合する
- 支払方法関連（`payment_method`, `card_brand`, `credit_reference_number`, `order_code`, `card_changed_at`）は BridgePlus・Bridge 両方に存在するが、`payment_method` のみ `orders.payment_method` として実装済み。カード情報・与信参照番号等は **未実装（R5 決済。`payment_transactions` 系。§13）**。カード情報自体はネットムーブ会員ID（`netmove_member_id`）で引き継ぐ前提（04 R5・netmove-card-migration.md）
- `num_employees` / `num_offices` は実装では `integer`（旧設計 UNSIGNED SMALLINT。`numericality: only_integer, >= 0` で検証）
- `applicant_type` の確定値: `法人` / `個人事業主`（BridgePlus CSV実データより）。Bridge側で「個人」があるか確認中
- `invoice_destination` の確定値: `設置先住所と同一` / `契約者住所と同一`（実データより確認）。他の値は確認中
- `years_in_business` はBridgePlusでは数値（旧システムの仕様確認中）、Bridgeでは「1年から5年」等の選択肢文字列

---

## 9. stores（店舗。旧 jasmin_stores）

**モデル名:** `Store`（`app/models/store.rb`。決定D により `JasminStore` → `Store`）
**テーブル名:** `stores`（旧設計名 `jasmin_stores`）
**実装状況:** 実装済み（R2 タスク1）。列は設計どおり（`jasmin_customer_id` → `customer_id` のみ改名）。旧「実装変更メモ」の `address VARCHAR(500)` 単一列は Rails 版では最初から住所分割列で作成したため解消済み。
**用途:** `customers` に紐づく設置先店舗・施設を管理するテーブル。1顧客に複数店舗が紐づく（1:N）。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `customers` | belongsTo | `customer_id = customers.id`（FK on_delete: cascade） |
| `orders` | hasMany | 店舗に紐づく案件（`orders.store_id`。`dependent: :nullify`。実装済み） |
| `applications` | hasMany（逆参照） | `applications.store_id`（申込完了時に生成。§12-6-4） |

### カラム一覧

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `customer_id` | uuid | NOT NULL | - | FK, IDX | 紐づく顧客（customers.id）。顧客削除時カスケード（旧設計名 `jasmin_customer_id`） |
| `store_code` | string(20) | NULL | - | IDX | 店舗CD（例: S00000002751）。旧システムから移行する場合に格納。新規登録時はNULL可 |
| `store_name` | string(255) | NOT NULL | - | - | ご利用施設名称 |
| `store_name_kana` | string(255) | NULL | - | - | ご利用施設名称（フリガナ） |
| `postal_code` | string(8) | NULL | - | - | 郵便番号 |
| `prefecture` | string(20) | NULL | - | - | 都道府県 |
| `city` | string(50) | NULL | - | - | 市区郡 |
| `town` | string(100) | NULL | - | - | 町名 |
| `address_detail` | string(200) | NULL | - | - | 番地・ビル・建物名 |
| `phone_number` | string(20) | NULL | - | - | ご連絡先電話番号 |
| `fax_number` | string(20) | NULL | - | - | ご連絡先FAX番号 |
| `business_hours_1` | string(50) | NULL | - | - | 営業時間1（例: 15:00～10:00） |
| `business_hours_2` | string(50) | NULL | - | - | 営業時間2 |
| `regular_holiday` | string(100) | NULL | - | - | 定休日（例: 年中無休 / 毎週月曜日 等） |
| `is_active` | boolean | NOT NULL | TRUE | IDX | 有効フラグ（false = 利用停止） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | - | FK | 作成ユーザID（users.id）。`TracksUser` concern が `Current.user` から自動設定 |
| `updated_by_id` | uuid | NULL | - | FK | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

### BridgePlus / Bridge 両方の店舗フィールド対照

> Bridge店舗の画面を確認済み。店舗情報のフィールドは **BridgePlus・Bridge 完全一致**。stores は両方を同一テーブルで管理できる。

### 店舗に紐づく案件情報（orders テーブル。実装済み）

店舗詳細画面下部の案件テーブルは `orders`（§10）で管理する。stores には持たない。

| 表示項目 | テーブル | BridgePlus値例 | Bridge値例 |
|---|---|---|---|
| 案件番号 | `orders.order_number` | BP002760 | BR101443 |
| ステータス | `orders.status` | 10:作業進行中 | 100:100:CLOSE |
| プラン | `orders.plan_id` → `plans.name` | スタンダード（E） | （空） |

> **注意:** Bridge店舗画面では案件番号列のラベルが「顧客番号」になっているが、値は「BR101443」形式の案件番号。BridgePlusの「案件番号（BP002760）」と同一概念。ラベルは旧システム側の表示名のため、新システムでは「案件番号」に統一する。
>
> ステータスの形式もBridgePlus（「10:作業進行中」）とBridge（「100:100:CLOSE」）で異なる。Rails 版では `order_statuses` マスタ（§12-4-2）に集約し、旧コード体系のまま code として登録・運用開始後に権限管理UIから追加する方針（正規化は R7 移行時に確定。要確認）。

### 実装変更メモ（旧Laravel。解消済み）

> 旧: `address VARCHAR(500)` の単一文字列カラムを住所分割カラム（postal_code〜address_detail）へ置き換える必要があった。
> Rails 版（`db/migrate/20260815140015_create_stores.rb`）は最初から分割列で作成しているため対応不要。
> 残課題（04 R2 追加タスク）: Store 一覧の検索・ページネーション、Store 向け CSV 非同期エクスポート（`CsvExport::EXPORTABLE_RESOURCE_TYPES` は Customer / Order のみ）は未実装。

---

## 10. orders（案件。旧 jasmin_orders）

**モデル名:** `Order`（`app/models/order.rb`。決定D により `JasminOrder` → `Order`）
**テーブル名:** `orders`（旧設計名 `jasmin_orders`）
**実装状況:** 実装済み（R2 タスク1。約90列）。実装との差分（いずれも実装を正とする）:
- **追加** `contract_condition_id`（uuid, NOT NULL, FK）: T-3 是正。受注時点の契約条件バージョンを案件側で固定参照（旧設計は customers 側）
- **追加** `payment_method`（string(50)）: 旧設計は `plans.payment_method`。案件ごとの入力値へ移設
- **追加** `product_initial_fee_id`（uuid, NULL, FK → product_initial_fees）: 旧設計は `plans.initial_fee`。商材の初期費用テンプレートから選択
- `status` は **NOT NULL・既定 `"0:受注"`**（`OrderStatus::CODE_ORDERED`。旧設計は NULL 許可）。`order_statuses.code` を格納
- `billing_password` は **text・ENC**（ActiveRecord::Encryption。旧設計 VARCHAR(50)）
- `jasmin_customer_id` / `jasmin_store_id` → `customer_id` / `store_id`
- `order_number` の新規採番は `ORD{YYYY}{連番4桁}`（年別キー `order_number_YYYY` を `SequenceCounter` で払い出し）。旧 `BP`/`BR` prefix は移行データのみ（要確認: 新規採番形式は業務側未確定）
- 選択オプション（Plus 等）は `order_options`（§12-1-3。Order⇄ProductOption 中間）
**用途:** BridgePlus・Bridge の契約案件を管理するテーブル。1顧客×1店舗で1案件を基本単位とする。案件ごとのプラン・費用・日付・コール記録・書類・外部サービス申込等を保持する。GBP設定・SNSアカウント・キーワード等の作業詳細は `order_work_details` で管理。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `customers` | belongsTo | 契約顧客（FK on_delete: restrict） |
| `stores` | belongsTo | 設置先店舗（nullable。FK on_delete: nullify） |
| `sales_representatives` | belongsTo | 担当営業担当者（nullable。FK on_delete: nullify） |
| `agencies` | belongsTo | `agency_id = agencies.id`（販売代理店。案件一覧アクセス制御 = Pundit `AgencyScoped` に使用。FK on_delete: restrict） |
| `contract_conditions` | belongsTo | `contract_condition_id`（NOT NULL。T-3 是正。FK on_delete: restrict） |
| `plans` | belongsTo | `plan_id = plans.id`（プラン。nullable。FK on_delete: nullify） |
| `product_initial_fees` | belongsTo | `product_initial_fee_id`（初期費用。nullable。FK on_delete: nullify。§12-1-1） |
| `order_work_details` | hasOne | GBP/SNS作業詳細（`dependent: :destroy`） |
| `order_options` / `product_options` | hasMany / has_many through | 選択オプション（§12-1-3。`Order#product_option_ids=` を申込フォームの `target_column` から呼ぶ） |
| `applications` | hasMany | 申込トランザクション（`dependent: :nullify`。§12-6-4） |
| `inquiries` | hasMany（逆参照） | 問い合わせ・掲示板（`inquiries.order_id` NOT NULL。FK on_delete: restrict。§12-7-1） |

### カラム一覧

#### 基本・識別情報

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `order_number` | string(20) | NOT NULL | - | UQ | 案件番号。移行データ: BridgePlus `BPxxxxxxx` / Bridge `BRxxxxxxx`。新規: `Order#assign_order_number` が `ORD{YYYY}{%04d}`（`SequenceCounter.next_value!("order_number_#{year}")`）で採番 |
| `customer_id` | uuid | NOT NULL | - | FK, IDX | 契約顧客（customers.id。旧設計名 `jasmin_customer_id`） |
| `store_id` | uuid | NULL | - | FK, IDX | 設置先店舗（stores.id。旧設計名 `jasmin_store_id`）。削除時NULL化 |
| `sales_representative_id` | uuid | NULL | - | FK, IDX | 担当営業担当者（sales_representatives.id）。削除時NULL化 |
| `agency_id` | uuid | NOT NULL | - | FK, IDX | 販売代理店（agencies.id）。案件一覧のアクセス制御に使用。代理店ユーザは自代理店の案件のみ参照可能。代理店グループユーザは傘下代理店全案件を参照可能 |
| `contract_condition_id` | uuid | NOT NULL | - | FK, IDX | 受注時点の契約条件バージョン（contract_conditions.id。**T-3 是正で実装追加**。on_delete: restrict） |
| `serial_id` | string(20) | NULL | - | - | シリアルID（旧システムの案件番号と同値。レガシー保持用） |

#### プラン・初期費用・支払方法

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `plan_id` | uuid | NULL | プラン（plans.id。FK, IDX）。月額料金等の詳細は `plans` テーブルを参照 |
| `product_initial_fee_id` | uuid | NULL | 初期費用テンプレート（product_initial_fees.id。FK, IDX。**実装追加**。旧設計 `plans.initial_fee` の移設先） |
| `payment_method` | string(50) | NULL | 支払方法（例: 預金口座振替 / クレジット。**実装追加**。旧設計 `plans.payment_method` の移設先） |
| `plus_applied` | string(5) | NULL | Plus申込有無（この案件固有の申込状態）。オプションの実体は `order_options`（§12-1-3） |

#### ステータス

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `status` | string(50) | **NOT NULL**（既定 `"0:受注"`, IDX） | 案件ステータス（呼称は「案件ステータス」に統一済み。status-naming-analysis.md 案A）。`order_statuses.code` を格納（DB FK なし。`status_must_exist_in_order_statuses` で検証）。既定集合（`StatusSeeder::ORDER_STATUSES`）: `0:受注`（is_system）/ `10:作業進行中` / `21:解約` / `22:強制解約` / `100:CLOSE`。BridgePlus/Bridge の旧コード体系は運用開始後にマスタへ追加 |
| `contract_status` | string(10) | NULL | 契約ステータス（数値コード。例: 4）。R5 契約フロー状態機械で意味づけ予定 |

#### 日付管理

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `ordered_at` | date | NULL | 受注日（申込日） |
| `contract_start_date` | date | NULL | 契約開始日（確認コール完了日） |
| `contract_sent_at` | date | NULL | 契約書送付日 |
| `issued_at` | date | NULL | 発注日 |
| `account_issued_at` | date | NULL | アカウント発行日 |
| `work_completed_at` | date | NULL | 作業完了日（納品完了メール送付日） |
| `accounting_month` | string(6) | NULL | 計上月（例: 202304）。BridgePlus側 |
| `bridge_accounting_month` | string(6) | NULL | Bridge計上月。Bridge移行案件用 |
| `payment_collected_at` | date | NULL | 決済回収日 |
| `payment_doc_confirmed_at` | date | NULL | 決済書類確認日 |
| `cancelled_at` | date | NULL | キャンセル日 |
| `terminated_at` | date | NULL | 解約日 |
| `termination_reason` | string(200) | NULL | 解約理由 |

#### 確認コール情報

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `confirm_call_staff_name` | string(50) | NULL | 確認コール架電担当名 |
| `confirm_call_notes` | text | NULL | 確認コール詳細（架電履歴・対応内容を含む長文テキスト） |
| `confirm_call_preferred_date` | string(50) | NULL | 確認コール連絡希望日 |
| `confirm_call_time` | string(100) | NULL | 確認コール架電時間（例: ②PM 12 時～ 15 時）...） |
| `confirm_call_contact_name` | string(50) | NULL | 確認コール担当者名（顧客側の対応者） |
| `confirm_call_remarks` | text | NULL | 確認コール備考 |

#### 検収コール情報

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `inspection_call_ng_time` | string(100) | NULL | 検収コールNG時間帯 |
| `inspection_call_history` | text | NULL | 検収コール履歴（架電ログ） |
| `inspection_call_completed_at` | date | NULL | 検収確認コール完了日 |

#### 書類・同意

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `elderly_consent` | string(5) | NULL | 高齢者同意書（あり / NULL） |
| `elderly_consent_collected_at` | date | NULL | 高齢者同意書回収日 |
| `business_auth_doc` | string(5) | NULL | 業務権限証明書（あり / NULL） |
| `business_auth_doc_collected_at` | date | NULL | 業務権限証明書回収日 |
| `business_proof` | string(200) | NULL | 個人事業主の場合事業証明（URLや記録） |
| `consent_status` | string(20) | NULL | 同意状況（例: 同意） |
| `consent_rep_age` | integer | NULL | 同意時 代表者年齢 |
| `consent_contact_age` | integer | NULL | 同意時 担当者年齢 |
| `paper_address_note` | string(200) | NULL | 用紙の送付先住所記載 |

#### 財務・請求

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `sales_mgmt_slip_number` | string(20) | NULL | 販管売上伝票番号 |
| `factor_notes` | string(200) | NULL | ファクター回収備考 |
| `bundled_billing` | string(5) | NULL | おまとめ請求（する / しない） |
| `bundle_target_order_number` | string(20) | NULL | おまとめ先の案件番号 |
| `discount_option` | string(50) | NULL | 割引オプション（割引なし / 長期割引（税込11,000円） / 長期割引（税込22,000円）。**実装追加 2026-08-21**・AILINK申込フォームP2 オプション②。Q-46利用規約自動切替がR5で参照） |
| `finance_division` | string(20) | NULL | 信販区分 |
| `finance_installer` | string(100) | NULL | 設置先（アシスト信販） |
| `finance_postal_code` | string(8) | NULL | 設置先郵便番号（信販用） |
| `finance_prefecture` | string(20) | NULL | 設置先_都道府県（信販用） |
| `finance_city` | string(50) | NULL | 設置先_市区町村（信販用） |
| `finance_town` | string(100) | NULL | 設置先_町名（信販用） |
| `finance_address_detail` | string(100) | NULL | 設置先_番地（信販用） |
| `finance_building` | string(100) | NULL | 設置先_ビル名（信販用） |
| `finance_phone` | string(20) | NULL | 設置先電話番号（信販用） |

#### 外部システム連携

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `member_id` | string(20) | NULL | 会員管理ID（例: B236690368） |
| `billing_password` | text | NULL | 請求パスワード。**ENC**（`encrypts :billing_password`。pii-handling-rules.md 分類B。暗号文が長くなるため text。`Auditable` 追跡対象外） |
| `meo_mgmt_number` | string(20) | NULL | MEO施策管理番号（例: pa00011610） |
| `toss_up_code` | string(20) | NULL | トスアップCD |

#### Bridge移行情報

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `bridge_migration` | string(5) | NULL | Bridge移行フラグ（あり / なし） |
| `bridge_migration_order_number` | string(20) | NULL | Bridge移行案件番号 |
| `bridge_agency_name` | string(100) | NULL | Bridge販売店名（移行前の代理店名記録用） |
| `bridge_sales_rep_name` | string(50) | NULL | Bridge営業担当者名（移行前の担当者記録用） |

#### 追加サービス申込

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `citation_applied` | string(5) | NULL | サイテーション申し込み |
| `citation_count` | integer | NULL | サイテーション申し込み数 |
| `citation_existing_serial` | string(50) | NULL | サイテーション既存シリアル |
| `domestic_citation_plan` | string(50) | NULL | 国内サイテーションプラン |
| `citation_plan` | string(50) | NULL | サイテーションプラン |
| `s_plan_cms` | string(5) | NULL | Sプラン CMS申込 |
| `owlet_cms` | string(5) | NULL | Owlet CMS申込 |
| `onerank_cms` | string(5) | NULL | Onerank CMS申込 |
| `external_link_applied` | string(5) | NULL | 外部リンク申し込み |
| `external_link_count` | integer | NULL | 外部リンク申し込み数 |
| `external_link_type` | string(20) | NULL | 外部リンクの型（例: ストック型） |
| `gbp_multilingual` | string(5) | NULL | GBPインバウンド多言語対策 |
| `language_selection` | string(100) | NULL | 言語選択 |
| `meo_existing_serial` | string(50) | NULL | MEO既存シリアル |
| `infobiz_applied` | string(5) | NULL | info Biz申し込み |
| `meo_premium_applied` | string(5) | NULL | MEOプレミアム強化プランの申し込み |
| `google_ads_applied` | string(5) | NULL | Google広告申し込み |
| `google_ads_count` | integer | NULL | Google広告申し込み数 |
| `google_review_display` | string(5) | NULL | Google口コミ表示 |
| `review_heading` | string(100) | NULL | 口コミ表示の見出し名 |
| `reservation_system` | string(50) | NULL | 予約システム |
| `portal_site_applied` | string(5) | NULL | ポータルサイト掲載の申し込み |

#### メモ・備考

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `remarks` | text | NULL | 備考 |
| `shared_notes` | text | NULL | 共有事項 |

#### 管理カラム

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `created_at` | datetime | NOT NULL | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | 作成ユーザID（users.id）。`TracksUser` concern が自動設定 |
| `updated_by_id` | uuid | NULL | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

### CSVとの対応：customers / stores に持つため orders には不要な列

| CSV列 | 参照先テーブル |
|---|---|
| 顧客番号、契約者名・カナ、業種、請求書送付先情報 | `customers` |
| 会員管理ID → `netmove_member_id` として管理済み | `customers` |
| ご利用施設名称、店舗住所、営業時間 | `stores` |
| グループCD・名、販売店CD・名 | `agency_groups` / `agencies` |
| 営業担当者コード・名 | `sales_representatives` |
| GBP設定情報・SNSアカウント・キーワード | `order_work_details` |

### 備考

- `status` の形式: BridgePlusは「10:作業進行中」、Bridgeは「100:100:CLOSE」等と形式が異なる。格納は string で統一し `order_statuses` マスタで管理。コード体系の正規化は R7 移行時に確定（要確認）。ステータス遷移バリデーション（不正遷移の防止）は **未実装（R6）**
- プラン（月額料金）は `plans`、初期費用は `product_initial_fees`、支払方法は `orders.payment_method`、オプションは `product_options` / `order_options` で管理する（実装に合わせて分解）
- 決済トランザクション（ネットムーブ連携）・契約書PDF・署名は **未実装（R5）**。§13 参照
- `consent_rep_age` / `consent_contact_age` / `citation_count` / `external_link_count` / `google_ads_count` は実装では `integer`（旧設計 UNSIGNED TINYINT。`numericality` で検証）
- 「未収情報フィールド（未回収額等）」の追加要否は 04 R2 追加タスクで要判断（`sales_mgmt_slip_number` は実装済み）
- アポインター担当者コード/名はcustomersで管理（案件ではなく顧客レベルの属性のため）
- `confirm_call_notes` / `inspection_call_history` は非常に長い履歴テキストを含むためTEXT型

---

## 11. order_work_details（案件作業詳細。旧 jasmin_order_work_details）

**モデル名:** `OrderWorkDetail`（`app/models/order_work_detail.rb`。決定D により `JasminOrderWorkDetail` → `OrderWorkDetail`）
**テーブル名:** `order_work_details`（旧設計名 `jasmin_order_work_details`）
**実装状況:** 実装済み（R2 タスク2）。実装との差分: `jasmin_order_id` → `order_id`。システムアカウント / Google / Instagram / Facebook の ID・PASS 8列は **text・ENC**（`encrypts`。pii-handling-rules.md 分類B。旧設計 VARCHAR(100)）。それ以外の列・長さは設計どおり。
**用途:** 案件ごとのGBP設定・SNSアカウント・キーワード・作業記録・店舗詳細情報を管理するテーブル。`orders` との1:1関係。基本契約データと作業詳細を分離することで、参照・更新権限の制御や将来のスキーマ変更を容易にする。

### リレーション

| 関連テーブル | 種別 | 条件 |
|---|---|---|
| `orders` | belongsTo | `order_id = orders.id`（1:1。FK on_delete: cascade） |

### カラム一覧

#### 識別

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー（UUID v4） |
| `order_id` | uuid | NOT NULL | - | FK, UQ | orders.id（1:1。旧設計名 `jasmin_order_id`） |

#### システムアカウント

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `system_account_id` | text | NULL | システムアカウントID。**ENC** |
| `system_account_pass` | text | NULL | システムアカウントPASS。**ENC** |
| `google_account_id` | text | NULL | GoogleアカウントID。**ENC** |
| `google_account_pass` | text | NULL | GoogleアカウントPASS。**ENC** |

> 8列（本節 + Instagram/Facebook の ID/PASS）は `ActiveRecord::Encryption`（`deterministic: false`）。等価検索は行わない前提。`Auditable` の追跡対象に含めない。

#### Instagram / Facebook

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `instagram_account` | string(20) | NULL | Instagramアカウント所持区分（既存あり / 新規取得） |
| `instagram_id` | text | NULL | Instagram ID。**ENC** |
| `instagram_pass` | text | NULL | Instagram PASS。**ENC** |
| `instagram_login_confirmed` | string(20) | NULL | Instagramアカウントのログイン確認状況 |
| `facebook_id` | text | NULL | FacebookID。**ENC** |
| `facebook_pass` | text | NULL | FacebookPASS。**ENC** |
| `has_facebook` | string(10) | NULL | Facebookアカウントの所持（あり / なし） |
| `has_facebook_page` | string(20) | NULL | Facebookページの所持（既に保有している / お客さまにて作成予定 / 代行・補助希望。**実装追加 2026-08-21**・AILINK申込フォームP9） |
| `has_instagram` | string(10) | NULL | Instagramアカウントの所持（あり / なし） |
| `has_line` | string(20) | NULL | LINEアカウントの所持（既に保有している / お客さまにて作成予定 / 代行・補助希望。**実装追加 2026-08-21**・AILINK申込フォームP9） |
| `has_google_business` | string(10) | NULL | Googleビジネスアカウントの所持（あり / なし） |

#### GBP（Google ビジネスプロフィール）

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `gbp_permission` | string(30) | NULL | GBP権限（お客様所持 / etc.） |
| `gbp_owner_permission` | string(20) | NULL | オーナー権限（わかる / 不明） |
| `gbp_owner_name` | string(100) | NULL | オーナー権限所有者名・担当者名 |
| `gbp_owner_contact` | string(100) | NULL | オーナー権限所有者・担当者連絡先 |
| `gbp_owner_permission_granted` | string(20) | NULL | オーナー権限付与（作業完了フラグ） |
| `gbp_url` | string(500) | NULL | Google ビジネスプロフィール URL |
| `gbp_site_url` | string(500) | NULL | ビジネスプロフィールのサイトURL |
| `gbp_delete_new` | string(10) | NULL | 既存GBP削除し、新規作成希望 |
| `reference_url` | string(500) | NULL | お客様情報参考サイトURL |

#### キーワード設定

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `keyword_region_industry` | string(200) | NULL | キーワード（地域＋業種） |
| `keyword_prefecture` | string(20) | NULL | キーワード_都道府県 |
| `keyword_city` | string(50) | NULL | キーワード_市町村 |
| `keyword_area_1` | string(50) | NULL | キーワード_通称エリア名1 |
| `keyword_area_2` | string(50) | NULL | キーワード_通称エリア名2 |
| `keyword_area_3` | string(50) | NULL | キーワード_通称エリア名3 |
| `keyword_industry_main` | string(50) | NULL | 業種やサービス_メイン |
| `keyword_industry_sub1` | string(50) | NULL | 業種やサービス_サブ1 |
| `keyword_industry_sub2` | string(50) | NULL | 業種やサービス_サブ2 |
| `keyword_industry_sub3` | string(50) | NULL | 業種やサービス_サブ3 |
| `keyword_industry_sub4` | string(50) | NULL | 業種やサービス_サブ4 |
| `keyword_remarks` | text | NULL | キーワード備考（通称エリア設定理由等） |
| `business_category_keyword` | string(200) | NULL | キーワード(ビジネスカテゴリー) |
| `industry_keyword` | string(200) | NULL | 業種キーワード |

#### 店舗詳細（GBP登録用）

> ヒアリングシートから取得する店舗詳細情報。`stores` の基本情報を補完するGBP設定用フィールド。

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `business_type` | string(30) | NULL | 業態（例: 店舗型） |
| `opening_date` | date | NULL | 開業日 |
| `num_employees` | integer | NULL | 従業員数 |
| `capital` | string(50) | NULL | 資本金（法人の場合必須。文字列で格納） |
| `nearest_station` | string(100) | NULL | 最寄駅 |
| `directions` | string(500) | NULL | 道順 |
| `parking` | string(20) | NULL | 駐車場（あり / なし） |
| `parking_capacity` | integer | NULL | 駐車可能な台数 |
| `barrier_free` | string(10) | NULL | バリアフリーの有無 |
| `wifi_available` | string(30) | NULL | 設備：Wi-Fiの有無（なし / 無料Wi-Fi / 有料Wi-Fi） |
| `accepted_cards` | string(200) | NULL | 利用できるクレジットカードの種類 |
| `logo_photo` | string(100) | NULL | ロゴ・写真データなど（状況メモ） |
| `num_stores` | integer | NULL | ご利用の店舗数 |
| `business_account_name` | string(100) | NULL | ビジネスアカウント名 |
| `lunch_hours` | string(30) | NULL | ランチ営業時間 |
| `dinner_hours` | string(30) | NULL | ディナー営業時間 |
| `available_from` | string(30) | NULL | 入店可能時間 |
| `order_time` | string(30) | NULL | 注文可能時間 |
| `attribute_1` | string(100) | NULL | 属性1 |
| `attribute_2` | string(100) | NULL | 属性2 |
| `attribute_3` | string(100) | NULL | 属性3 |
| `attribute_4` | string(100) | NULL | 属性4 |
| `attribute_5` | string(100) | NULL | 属性5 |
| `attribute_6` | string(100) | NULL | 属性6 |
| `attribute_7` | string(100) | NULL | 属性7 |
| `attribute_8` | string(100) | NULL | 属性8 |
| `attribute_9` | string(100) | NULL | 属性9 |
| `attribute_10` | string(100) | NULL | 属性10 |
| `attribute_11` | string(100) | NULL | 属性11 |

#### 連絡・ヒアリング

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `hearing_system` | string(50) | NULL | ヒアリングシステム |
| `contact_easy_time` | string(100) | NULL | 連絡が取りやすい時間帯 |
| `contact_easy_time_note` | string(200) | NULL | 連絡が取りやすい時間帯【その他】 |
| `contact_easy_day` | string(100) | NULL | 連絡が取りやすい曜日 |
| `contact_easy_day_note` | string(200) | NULL | 連絡が取りやすい曜日【その他】 |

#### 作業記録（運用）

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `operation_history` | text | NULL | 履歴記載枠（運用）。運用中の対応記録・掲示板ログ等を含む長文テキスト |
| `work_progress_notes` | text | NULL | 作業進行備考。アカウント発行〜納品までの作業メモ |

#### 管理カラム

| カラム名 | 型 | NULL | 説明 |
|---|---|---|---|
| `created_at` | datetime | NOT NULL | 作成日時（Rails `timestamps`） |
| `updated_at` | datetime | NOT NULL | 更新日時（Rails `timestamps`） |
| `created_by_id` | uuid | NULL | 作成ユーザID（users.id）。`TracksUser` concern が自動設定 |
| `updated_by_id` | uuid | NULL | 更新ユーザID（users.id）。`TracksUser` concern が自動設定 |

### 備考

- `operation_history` / `work_progress_notes` は非常に長い自由入力テキストのためTEXT型
- GBPヒアリングシート内の代表者名・住所・電話等は `customers` / `stores` と重複するため格納しない
- `attribute_1`〜`attribute_11` の具体的な意味は実データ確認中（業態・設備等の属性情報と推定）
- 将来的に `operation_history` は専用の `order_histories` テーブルへの移行を検討（未実装。掲示板ログの実体は R4 の `inquiries` / `inquiry_messages` に統合。過去データは R7 アーカイブ投入）
- `num_employees` / `parking_capacity` / `num_stores` は実装では `integer`（旧設計 UNSIGNED SMALLINT/TINYINT）

## 12. R0〜R4 で追加された実装済みテーブル

旧 Column.md（§1〜§11）に無く、Rails 実装（R0〜R4）で追加されたテーブル。列定義は `db/schema.rb` から機械抽出（2026-08-19）し、説明はモデルコメント（annotaterb 注釈・冒頭コメント）に基づく。`id` / `created_at` / `updated_at` / `created_by_id` / `updated_by_id` の規約は §0 参照。FK 表記の `on_delete` 無指定は既定（restrict 相当）。

### 12-1. 商材・オプション系（R2 タスク3 / R3）

### 12-1-1. product_initial_fees

**モデル名:** `ProductInitialFee`　**テーブル名:** `product_initial_fees`　**実装状況:** 実装済み（R2 タスク3）

**用途:** 商材の初期費用テンプレート。旧設計 `plans.initial_fee` の移設先。案件は `orders.product_initial_fee_id` で選択値を参照（FK on_delete: nullify）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `amount` | integer | NOT NULL | - | - | 初期費用（円） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ |
| `name` | string(100) | NOT NULL | - | - | 名称（例: 初期費用 50,000円） |
| `product_id` | uuid | NOT NULL | - | FK (→products, on_delete: cascade), IDX（複合: product_id, sort_order） | 商材（products.id） |
| `sort_order` | integer | NOT NULL | 0 | IDX（複合: product_id, sort_order） | 表示順 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo products（on_delete: cascade）/ hasMany orders。`Auditable`: name / amount / product_id / is_active。

### 12-1-2. product_options

**モデル名:** `ProductOption`　**テーブル名:** `product_options`　**実装状況:** 実装済み（R2 タスク3）

**用途:** 商材のオプション（Plus 等）マスタ。旧設計 `plans.plus_flag` の代替。案件との紐づけは `order_options`。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `description` | text | NULL | - | - | 説明 |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ |
| `monthly_fee` | integer | NULL | - | - | オプション月額（円） |
| `name` | string(100) | NOT NULL | - | - | オプション名（例: Plus） |
| `product_id` | uuid | NOT NULL | - | FK (→products, on_delete: cascade), IDX（複合: product_id, sort_order） | 商材（products.id） |
| `sort_order` | integer | NOT NULL | 0 | IDX（複合: product_id, sort_order） | 表示順 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo products（on_delete: cascade）/ hasMany order_options。

### 12-1-3. order_options

**モデル名:** `OrderOption`　**テーブル名:** `order_options`　**実装状況:** 実装済み（R3 タスク5。旧 jasmin_order_options 相当）

**用途:** Order⇄ProductOption 中間テーブル。業務ロジックは持たず、`Order#product_option_ids=`（has_many :through の集合idsライター）経由で `Form::ApplicationSubmissionService` から作成される。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `order_id` | uuid | NOT NULL | - | FK (→orders, on_delete: cascade), UQ（複合: order_id, product_option_id） | 案件（orders.id） |
| `product_option_id` | uuid | NOT NULL | - | FK (→product_options, on_delete: restrict), UQ（複合: order_id, product_option_id）, IDX | 選択したオプション（product_options.id） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> リレーション: belongsTo orders（on_delete: cascade）/ belongsTo product_options（on_delete: restrict）。`created_by_id` / `updated_by_id` は持たない。

### 12-1-4. agency_group_products

**モデル名:** `AgencyGroupProduct`　**テーブル名:** `agency_group_products`　**実装状況:** 実装済み（R2 タスク3。管理UI未実装）

**用途:** Product×AgencyGroup の販売許可中間テーブル（旧設計は代理店単位 `agency_products` のみ）。`Product.sellable_by` が代理店とグループ双方の許可を見る。管理画面からの付与/剥奪 UI は未実装（04 R2 追加タスク）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `agency_group_id` | uuid | NOT NULL | - | FK (→agency_groups, on_delete: cascade), UQ（複合: agency_group_id, product_id） | 代理店グループ（agency_groups.id） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `product_id` | uuid | NOT NULL | - | FK (→products, on_delete: cascade), UQ（複合: agency_group_id, product_id）, IDX | 商材（products.id） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> リレーション: belongsTo agency_groups / products（いずれも on_delete: cascade）。

### 12-2. 認証・認可（R0 / R1。ftlog 式エンドポイント RBAC）

### 12-2-1. users

**モデル名:** `User`　**テーブル名:** `users`　**実装状況:** 実装済み（R0。R1 で agency_group_id / agency_id 追加）

**用途:** 管理画面ユーザー（社内 admin・実務運用者 / 代理店グループ担当者 / 代理店担当者）。Devise（database_authenticatable / registerable / recoverable / validatable / lockable / timeoutable）＋ `OtpAuthenticatable`（メールOTP）＋ `AuthAuditable`。旧設計 §1・§2 の「グループアカウント / 代理店アカウント」の実体。受注入力（SalesRepresentative）・マイページ（Customer）は別モデル（03§4 決定D）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `agency_group_id` | uuid | NULL | - | FK (→agency_groups, on_delete: restrict), IDX | 所属代理店グループ（代理店グループ担当者のみ設定。R1 追加） |
| `agency_id` | uuid | NULL | - | FK (→agencies, on_delete: restrict), IDX | 所属代理店（代理店担当者のみ設定。R1 追加）。`agency_group_id` との同時設定は禁止（`User#agency_scope_is_exclusive`） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `email` | string | NOT NULL | "" | UQ | ログインID（Devise 認証キー）。代理店/グループアカウントは `agencies.email_1` 等とは別管理 |
| `encrypted_password` | string | NOT NULL | "" | - | Devise database_authenticatable |
| `failed_attempts` | integer | NOT NULL | 0 | - | Devise lockable（失敗回数） |
| `is_active` | boolean | NOT NULL | true | - | 有効フラグ（false=ログイン不可） |
| `locked_at` | datetime | NULL | - | - | Devise lockable（ロック日時） |
| `name` | string | NOT NULL | "" | - | 氏名（表示名） |
| `otp_attempts` | integer | NOT NULL | 0 | - | メールOTP失敗回数（`OtpAuthenticatable`。5回でロック） |
| `otp_code_digest` | string | NULL | - | - | メールOTPダイジェスト |
| `otp_code_expires_at` | datetime | NULL | - | - | OTP有効期限（10分） |
| `reset_password_sent_at` | datetime | NULL | - | - | Devise recoverable |
| `reset_password_token` | string | NULL | - | UQ | Devise recoverable |
| `unlock_token` | string | NULL | - | UQ | Devise lockable |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> リレーション: belongsTo agency_groups / agencies（optional。FK on_delete: restrict = 2026-08-16 変更）/ has_many system_roles through user_system_roles。
> `agency_group_id` と `agency_id` の両方 NULL = 社内ユーザー（Pundit `AgencyScoped.staff_scope` 全件）。両方設定は禁止。`Auditable`: name / email / is_active / agency_group_id / agency_id。

### 12-2-2. system_roles

**モデル名:** `SystemRole`　**テーブル名:** `system_roles`　**実装状況:** 実装済み（R0）

**用途:** エンドポイント RBAC のロール。ftlog の SystemRole から acts_as_tenant・portal フラグを除去した単一テナント版。`RoleSeeder` が組み込み4ロールを冪等作成。mypage / form セクションはロール割当を使わないため実質 admin セクション専用。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `description` | text | NULL | - | - | 説明文 |
| `display_name` | string | NULL | - | - | 表示名 |
| `name` | string | NOT NULL | - | UQ | ロール名（固定キー。組み込み4ロール: `admin` / `実務運用者` / `代理店グループ用` / `代理店用` = `SystemRole::BUILT_IN_ROLE_ATTRIBUTES`。Laravel現行の名称を維持） |
| `position` | integer | NULL | - | IDX | 表示順 |
| `super_admin` | boolean | NOT NULL | false | - | true=全権限（`admin` ロール） |
| `system` | boolean | NOT NULL | false | IDX | true=組み込みロール（name 変更・削除禁止） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: has_many system_permissions through system_role_permissions / has_many users through user_system_roles。

### 12-2-3. system_permissions

**モデル名:** `SystemPermission`　**テーブル名:** `system_permissions`　**実装状況:** 実装済み（R0）

**用途:** ルート署名（controller / action / http_method / path）を権限単位にしたグローバルカタログ。`SystemPermissionSyncService` が起動時にルートから同期し、`SystemPermissionChecker` が ApplicationController でフェイルクローズ判定する（未登録ルートは拒否）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `action` | string | NOT NULL | - | UQ（複合: controller, action, http_method, path） | コントローラアクション名（ルート署名の一部） |
| `controller` | string | NOT NULL | - | UQ（複合: controller, action, http_method, path） | コントローラ名（例: `admin/customers`） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `enabled` | boolean | NOT NULL | true | IDX | 有効フラグ（false=全ロールで拒否） |
| `http_method` | string | NOT NULL | - | UQ（複合: controller, action, http_method, path） | HTTPメソッド（GET/POST/PATCH/DELETE 等） |
| `name` | string | NULL | - | - | 表示名（任意） |
| `path` | string | NOT NULL | - | UQ（複合: controller, action, http_method, path） | ルートパス（ルート署名の一部） |
| `section` | string | NOT NULL | "admin" | IDX | 区分: `admin` / `form` / `mypage`（`SystemPermission::SECTIONS`。既定 admin） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> `created_by_id` / `updated_by_id` は持たない（同期対象のため）。

### 12-2-4. system_role_permissions

**モデル名:** `SystemRolePermission`　**テーブル名:** `system_role_permissions`　**実装状況:** 実装済み（R0）

**用途:** ロール⇄権限の中間テーブル。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `system_permission_id` | uuid | NOT NULL | - | FK (→system_permissions), IDX, UQ（複合: system_role_id, system_permission_id） | 権限（system_permissions.id） |
| `system_role_id` | uuid | NOT NULL | - | FK (→system_roles), UQ（複合: system_role_id, system_permission_id） | ロール（system_roles.id） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

### 12-2-5. user_system_roles

**モデル名:** `UserSystemRole`　**テーブル名:** `user_system_roles`　**実装状況:** 実装済み（R0）

**用途:** ユーザー⇄ロールの中間テーブル（単一テナントのため組織一致バリデーションは無し）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `system_role_id` | uuid | NOT NULL | - | FK (→system_roles), IDX, UQ（複合: user_id, system_role_id） | ロール（system_roles.id） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `user_id` | uuid | NOT NULL | - | FK (→users), UQ（複合: user_id, system_role_id） | ユーザー（users.id） |

### 12-2-6. ip_allowlist_entries

**モデル名:** `IpAllowlistEntry`　**テーブル名:** `ip_allowlist_entries`　**実装状況:** 実装済み（R0-4 / P4-17）

**用途:** 接続元 IP 許可リスト。全画面2要素認証必須（Q-23・D-5）が前提のため常に効く。空リストは「全員OTP必須」のフェイルセーフ。rack-attack と併用。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `cidr` | string | NOT NULL | - | UQ | 許可する CIDR（例: `203.0.113.0/24`）。空リストなら全員OTP必須（フェイルセーフ） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `note` | string | NULL | - | - | 備考 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> `Auditable`: cidr / note。

### 12-3. 監査ログ（R0-7）

### 12-3-1. audit_logs

**モデル名:** `AuditLog`　**テーブル名:** `audit_logs`　**実装状況:** 実装済み（R0-7）

**用途:** 監査ログ本体（旧 spatie/activitylog の代替）。`Auditable` concern がモデルの `TRACKED_FIELDS` 差分を、`AuthAuditable` / `OtpAuthenticatable` が認証イベントを記録する。ログイン履歴画面（admin/login_histories）は本テーブルを `AuthAuditable::AUTH_ACTIONS` で絞り込むビュー（専用テーブルは持たない）。単一テナントのため organization_id 等は無い。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `action` | string | NOT NULL | - | IDX | 操作種別（`create` / `update` / `destroy` および `AuthAuditable::AUTH_ACTIONS`: login_succeeded / login_failed / account_locked / password_reset_* / otp_issued / otp_verified / otp_failed / permission_denied） |
| `changes_after` | jsonb | NULL | - | - | 変更後の値（`TRACKED_FIELDS` 対象列のみ） |
| `changes_before` | jsonb | NULL | - | - | 変更前の値（同上） |
| `created_at` | datetime | NOT NULL | - | IDX, IDX（複合: resource_type, resource_id, created_at） | 作成日時 |
| `ip_address` | string | NULL | - | - | リクエスト元IP |
| `metadata` | jsonb | NULL | - | - | 付帯情報（例: 権限拒否時の `route_signature`） |
| `request_id` | string | NULL | - | - | Rails request_id（同一リクエスト内の操作を束ねる） |
| `resource_id` | uuid | NULL | - | IDX（複合: resource_type, resource_id, created_at） | 対象レコードID（ポリモーフィック。DB FK なし） |
| `resource_label` | string | NULL | - | - | 対象の表示ラベル（name / display_name / cidr 等のスナップショット） |
| `resource_type` | string | NOT NULL | - | IDX（複合: resource_type, resource_id, created_at） | 対象モデル名（例: `Customer`, `SystemPermission`） |
| `source` | string | NULL | - | - | 発生元（`web` 等） |
| `user_id` | uuid | NOT NULL | - | IDX | 操作者ID（User / SalesRepresentative / Customer のいずれか。DB FK なし） |
| `user_type` | string | NOT NULL | - | - | 操作者のクラス名（`User` / `SalesRepresentative` / `Customer`） |

> `user_id` / `resource_id` は DB FK を張らない（操作者・対象ともポリモーフィック。削除後もログを残す）。`created_by_id` / `updated_by_id` / `updated_at` は持たない（追記専用）。

### 12-4. マスタ（R2 タスク4・6）

### 12-4-1. customer_statuses

**モデル名:** `CustomerStatus`　**テーブル名:** `customer_statuses`　**実装状況:** 実装済み（R2 タスク4）

**用途:** 顧客（申込）ステータスマスタ。`customers.status` はこの `code` を格納（旧設計 §8 の日本語ワークフロー値は `label`）。`SystemManagedStatus` concern（is_system 行の保護）。既定値は `StatusSeeder::CUSTOMER_STATUSES`。呼称は「申込ステータス」へ統一予定（Q-B・要対応）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `code` | string | NOT NULL | - | UQ | `customers.status` に格納されるコード（例: `applied`） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `is_active` | boolean | NOT NULL | true | IDX（複合: is_active, sort_order） | 有効フラグ（false=選択肢に出さない） |
| `is_system` | boolean | NOT NULL | false | - | true=コードから参照するシステム行（`applied` / `withdrawn`）。削除・code変更禁止 |
| `label` | string | NOT NULL | - | - | 表示ラベル（例: 申込受付） |
| `sort_order` | integer | NOT NULL | 0 | IDX（複合: is_active, sort_order） | 表示順 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> ステータス遷移バリデーションは未実装（R6）。

### 12-4-2. order_statuses

**モデル名:** `OrderStatus`　**テーブル名:** `order_statuses`　**実装状況:** 実装済み（R2 タスク4）

**用途:** 案件ステータスマスタ。`orders.status` はこの `code` を格納。既定値は `StatusSeeder::ORDER_STATUSES`（`0:受注` is_system / 10:作業進行中 / 21:解約 / 22:強制解約 / 100:CLOSE）。BridgePlus/Bridge の旧コード体系は運用開始後にUIから追加。`form_fields.lock_after_status` からも参照。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `code` | string | NOT NULL | - | UQ | `orders.status` に格納されるコード（例: `0:受注` `10:作業進行中`） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `is_active` | boolean | NOT NULL | true | IDX（複合: is_active, sort_order） | 有効フラグ |
| `is_system` | boolean | NOT NULL | false | - | true=システム行（`0:受注`）。削除・code変更禁止 |
| `label` | string | NOT NULL | - | - | 表示ラベル（例: 受注 / 作業進行中） |
| `sort_order` | integer | NOT NULL | 0 | IDX（複合: is_active, sort_order） | 表示順 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

### 12-4-3. option_groups

**モデル名:** `OptionGroup`　**テーブル名:** `option_groups`　**実装状況:** 実装済み（R2 タスク4）

**用途:** 選択肢グループ（業種・支払方法等のカテゴリ）。`key` はコード側から参照する固定キー。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `description` | text | NULL | - | - | 説明 |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ |
| `key` | string | NOT NULL | - | UQ | コード側から参照する固定キー（例: `industry` `payment_method`） |
| `label` | string | NOT NULL | - | - | 表示名 |
| `sort_order` | integer | NOT NULL | 0 | IDX | 表示順 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

### 12-4-4. option_values

**モデル名:** `OptionValue`　**テーブル名:** `option_values`　**実装状況:** 実装済み（R2 タスク4）

**用途:** 選択肢値。`parent_id` の自己参照でツリー化（旧 kalnoy/nestedset の代替。FK on_delete: cascade）。無効化は論理削除。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `depth` | integer | NOT NULL | 0 | - | ツリー深さ（0=ルート） |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ（false=論理削除。既存データが旧ラベルを参照しうるため物理削除しない） |
| `label` | string | NOT NULL | - | - | 表示ラベル |
| `option_group_id` | uuid | NOT NULL | - | FK (→option_groups, on_delete: cascade), UQ（複合: option_group_id, value）, IDX | 所属グループ（option_groups.id） |
| `parent_id` | uuid | NULL | - | FK (→option_values, on_delete: cascade), IDX | 親選択肢（自己参照。旧 kalnoy/nestedset → parent_id 方式に置換） |
| `sort_order` | integer | NOT NULL | 0 | - | 表示順 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |
| `value` | string | NOT NULL | - | UQ（複合: option_group_id, value） | 格納値（グループ内で一意） |

> リレーション: belongsTo option_groups（on_delete: cascade）/ belongsTo parent（option_values.id, on_delete: cascade）/ hasMany children。

### 12-4-5. production_companies

**モデル名:** `ProductionCompany`　**テーブル名:** `production_companies`　**実装状況:** 実装済み（R2 タスク6）

**用途:** 制作会社マスタ。`recipient_group_members` のメンバー（`ProductionCompany`）として問い合わせ通知の宛先になる。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `contact_name` | string(50) | NULL | - | - | 担当者名 |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `email` | string(255) | NULL | - | - | メールアドレス（問い合わせ宛先グループのメンバーとして使用） |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ |
| `name` | string(100) | NOT NULL | - | - | 制作会社名 |
| `notes` | text | NULL | - | - | 備考 |
| `phone` | string(20) | NULL | - | - | 電話番号 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

### 12-4-6. sales_materials

**モデル名:** `SalesMaterial`　**テーブル名:** `sales_materials`　**実装状況:** 実装済み（R2 タスク6。ファイルアップロードUIは未実装）

**用途:** 営業資料マスタ（カテゴリ6種）。実ファイルは `file_path` で参照（Active Storage 化・アップロードUIは要確認）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `category` | string(50) | NULL | - | IDX | カテゴリ（`SalesMaterial::CATEGORIES`: 提案書 / 会社案内 / 価格表 / 製品カタログ / マニュアル / その他） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `description` | text | NULL | - | - | 説明 |
| `file_path` | string(500) | NOT NULL | - | - | ファイルパス（実ファイルアップロードUIは R2 スコープ外。Active Storage 化は要確認） |
| `file_size` | bigint | NOT NULL | - | - | ファイルサイズ（バイト） |
| `is_published` | boolean | NOT NULL | false | IDX | 公開フラグ |
| `mime_type` | string(100) | NOT NULL | - | - | MIME タイプ |
| `original_file_name` | string(255) | NOT NULL | - | - | 元ファイル名 |
| `sort_order` | integer | NOT NULL | 0 | - | 表示順 |
| `title` | string(255) | NOT NULL | - | - | タイトル |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

### 12-5. 採番（R2 タスク5）

### 12-5-1. sequence_counters

**モデル名:** `SequenceCounter`　**テーブル名:** `sequence_counters`　**実装状況:** 実装済み（R2 タスク5）

**用途:** 自動採番カウンタ。`SequenceCounter.next_value!(key)` が `INSERT ... ON CONFLICT (key) DO UPDATE SET value = value + 1 RETURNING value` の単一SQLでアトミックに次番号を払い出す（PostgreSQL ネイティブ SEQUENCE の `nextval()` と同等の重複防止）。旧Laravelの `count()+1`（T-1 系脆弱性）を置き換える。使用箇所: `Customer#assign_customer_number`（`C-%06d`）/ `Order#assign_order_number`（`ORD{YYYY}{%04d}`、年別キー）/ `Inquiry#assign_inquiry_number`（`INQ-%06d`）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `key` | string | NOT NULL | - | UQ | 採番キー（`customer_number` / `order_number_YYYY` / `inquiry_number`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `value` | bigint | NOT NULL | 0 | - | 現在値（`SequenceCounter.next_value!` が +1 して返す） |

> `created_by_id` / `updated_by_id` は持たない。並行作成時の重複が無いことは `spec/models/customer_spec.rb` / `order_spec.rb` で検証。

### 12-6. 申込フォーム・受注入力（R3）

### 12-6-1. form_templates

**モデル名:** `FormTemplate`　**テーブル名:** `form_templates`　**実装状況:** 実装済み（R3 タスク3）

**用途:** 申込フォーム定義（商材と 1:1。`form_templates.product_id` UQ）。P2 拡張後仕様の実体は配下の form_steps / form_fields。管理画面フォームビルダー（`Admin::FormTemplatesController`）でネスト保存。版管理は無い。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `is_active` | boolean | NOT NULL | true | - | 有効フラグ |
| `name` | string | NOT NULL | - | - | テンプレート名 |
| `product_id` | uuid | NOT NULL | - | FK (→products, on_delete: cascade), UQ | 商材（products.id）。商材と 1:1（UQ）。版管理は無い |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo products（on_delete: cascade）/ hasMany form_steps。

### 12-6-2. form_steps

**モデル名:** `FormStep`　**テーブル名:** `form_steps`　**実装状況:** 実装済み（R3 タスク3）

**用途:** 動的マルチステップの1画面分。`step_number` が表示順と `Form::ApplicationsController` の step/{n} を兼ねる。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `form_template_id` | uuid | NOT NULL | - | FK (→form_templates, on_delete: cascade), UQ（複合: form_template_id, step_number） | テンプレート（form_templates.id） |
| `name` | string | NOT NULL | - | - | ステップ名 |
| `step_number` | integer | NOT NULL | - | UQ（複合: form_template_id, step_number） | ステップ番号（表示順 = URL の step/{n}） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo form_templates（on_delete: cascade）/ hasMany form_fields。

### 12-6-3. form_fields

**モデル名:** `FormField`　**テーブル名:** `form_fields`　**実装状況:** 実装済み（R3 タスク3）

**用途:** フィールド定義（development-plan.md の target_table / target_column / editable_by_tier / lock_after_status を初期スキーマから採用）。`Form::ApplicationSubmissionService` が `target_table` のレコードへ `target_column=` で反映する。書き込み禁止列（システム列・FK・status）は `FormField` 側で検証。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `editable_by_tier` | string[] | NOT NULL | ["sales_representative"], null: false, array: true | IDX（GIN） | 編集可能な利用者層の配列（`sales_representative` / `agency` / `admin`。GIN index） |
| `field_key` | string | NOT NULL | - | UQ（複合: form_step_id, field_key） | フィールドキー（ステップ内で一意。`applications.form_data` のキー） |
| `field_type` | string | NOT NULL | - | - | 入力型（text / textarea / date / integer / boolean / select / checkbox_group） |
| `form_step_id` | uuid | NOT NULL | - | FK (→form_steps, on_delete: cascade), UQ（複合: form_step_id, field_key） | ステップ（form_steps.id） |
| `input_options` | jsonb | NOT NULL | {} | - | 入力オプション（選択肢等。管理画面では JSON テキストエリア経由で編集） |
| `label` | string | NOT NULL | - | - | 表示ラベル |
| `lock_after_status` | string | NULL | - | - | この案件ステータス以降は編集ロック（`order_statuses.code`。R4/R5 の再編集フロー向け） |
| `required` | boolean | NOT NULL | false | - | 必須フラグ |
| `sort_order` | integer | NOT NULL | 0 | - | 表示順 |
| `target_column` | string | NULL | - | - | 書き込み先カラム（集合idsライター `product_option_ids` も可） |
| `target_table` | string | NOT NULL | - | - | 書き込み先（`customer` / `store` / `order` / `order_work_detail`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |
| `validation_rules` | jsonb | NOT NULL | {} | - | バリデーションルール（jsonb） |

> リレーション: belongsTo form_steps（on_delete: cascade）。`(form_step_id, field_key)` UQ。

### 12-6-4. applications

**モデル名:** `Application`　**テーブル名:** `applications`　**実装状況:** 実装済み（R3 タスク5）

**用途:** 申込トランザクション（旧 Laravel Application モデル移植）。営業担当者ログイン後のマルチステップ進行状態。完了時に `Form::ApplicationSubmissionService` が1トランザクションで Customer + Store + Order（+ order_options）を生成し `customer_id / store_id / order_id` を埋める。`form_data` は PII を含みうるため `Auditable` 対象外（完了イベントのみコントローラから明示記録）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `agency_id` | uuid | NOT NULL | - | FK (→agencies, on_delete: restrict) | 代理店（sales_representative の所属をスナップショット） |
| `completed_at` | datetime | NULL | - | - | 完了日時 |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `current_step_number` | integer | NOT NULL | 1 | - | 現在のステップ番号 |
| `customer_id` | uuid | NULL | - | FK (→customers, on_delete: nullify) | 完了時に生成した顧客（customers.id） |
| `form_data` | jsonb | NOT NULL | {} | - | ステップごとの回答（`field_key => 値`。PII を含みうるため `Auditable` 対象外） |
| `order_id` | uuid | NULL | - | FK (→orders, on_delete: nullify) | 完了時に生成した案件（orders.id） |
| `product_id` | uuid | NOT NULL | - | FK (→products, on_delete: restrict) | 商材（products.id。form_template は product 経由で解決） |
| `sales_representative_id` | uuid | NOT NULL | - | FK (→sales_representatives, on_delete: restrict), IDX | 入力した営業担当者 |
| `status` | string | NOT NULL | "in_progress" | IDX | `in_progress` / `completed` |
| `store_id` | uuid | NULL | - | FK (→stores, on_delete: nullify) | 完了時に生成した店舗（stores.id） |
| `token` | string(64) | NOT NULL | - | UQ | 申込トークン（64桁 hex。URL 識別子） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo sales_representatives / agencies / products（on_delete: restrict）、customers / stores / orders（optional, on_delete: nullify）。

### 12-7. 問い合わせ・掲示板統合（R4 タスク1・2。決定D-11）

### 12-7-1. inquiries

**モデル名:** `Inquiry`　**テーブル名:** `inquiries`　**実装状況:** 実装済み（R4）

**用途:** 問い合わせ本体。旧掲示板4種（後確 / 制作対応 / 検収コール / アフター問合せ）を「案件番号単位のスレッド＋投稿ごとのステータス変更＝通知トリガー」の共通構造で1モデルに統合（board-implementation-options.md 推奨案①）。`after_*` 列はアフター問合せ固有。ステータスは enum ではなく `inquiry_statuses` マスタ参照。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `after_area` | string | NULL | - | - | アフター問合せ固有: 領域 |
| `after_type` | string | NULL | - | - | アフター問合せ固有: 種別 |
| `after_urgency` | string | NULL | - | - | アフター問合せ固有: 緊急度 |
| `category` | string | NOT NULL | - | IDX（複合: category, status） | 種別（`Inquiry::CATEGORIES`: 後確 / 制作対応 / 検収コール / アフター問合せ。旧掲示板4種を統合 = 決定D-11） |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `first_responder_name` | string | NULL | - | - | 一次対応者名 |
| `inquiry_number` | string | NOT NULL | - | UQ | 問い合わせ番号（`INQ-%06d`。`SequenceCounter` 採番） |
| `is_visible_to_agent` | boolean | NOT NULL | true | - | 代理店に表示するか |
| `next_responder_name` | string | NULL | - | - | 次回対応者名 |
| `order_id` | uuid | NOT NULL | - | FK (→orders, on_delete: restrict), IDX | 対象案件（orders.id）。案件番号単位のスレッド |
| `reception_channel` | string | NULL | - | - | 受付チャネル |
| `status` | string | NOT NULL | - | IDX（複合: category, status） | `inquiry_statuses.code`（category 単位の集合。DB FK なし。`status_must_exist_in_inquiry_statuses`）。既定は `Inquiry::DEFAULT_STATUS_CODES` |
| `title` | string | NULL | - | - | 件名 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo orders（on_delete: restrict）/ hasMany inquiry_messages。`Auditable`: 構造・状態を特定する列のみ。

### 12-7-2. inquiry_messages

**モデル名:** `InquiryMessage`　**テーブル名:** `inquiry_messages`　**実装状況:** 実装済み（R4）

**用途:** 問い合わせスレッドの投稿。添付は Active Storage（`has_many_attached :attachments`。個別サイズ・件数のみ検証、合計サイズは制限しない = 旧「合計10MB超でエラー」バグの回避）。メール送信は `InquiryMessageMailJob`（非同期）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `body` | text | NOT NULL | - | - | 本文（`Auditable` 対象外）。添付は Active Storage `has_many_attached :attachments`（最大5件・各50MB） |
| `created_at` | datetime | NOT NULL | - | IDX（複合: inquiry_id, created_at） | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `inquiry_id` | uuid | NOT NULL | - | FK (→inquiries, on_delete: cascade), IDX（複合: inquiry_id, created_at） | 問い合わせ（inquiries.id） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo inquiries（on_delete: cascade）/ hasMany inquiry_message_recipients。

### 12-7-3. inquiry_message_recipients

**モデル名:** `InquiryMessageRecipient`　**テーブル名:** `inquiry_message_recipients`　**実装状況:** 実装済み（R4）

**用途:** 投稿ごとの宛先展開（polymorphic。`RecipientResolver.resolve_from_order` / `.route_for` の戻り値）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `inquiry_message_id` | uuid | NOT NULL | - | FK (→inquiry_messages, on_delete: cascade), IDX | メッセージ（inquiry_messages.id） |
| `recipient_id` | uuid | NOT NULL | - | IDX（複合: recipient_type, recipient_id） | 宛先ID（polymorphic） |
| `recipient_type` | string | NOT NULL | - | IDX（複合: recipient_type, recipient_id） | 宛先クラス（`Agency` / `SalesRepresentative` / `Customer` / `User` / `RecipientGroup`） |
| `resolved_email` | string | NULL | - | - | 送信時に解決したメールアドレスのスナップショット（R4 追加） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> リレーション: belongsTo inquiry_messages（on_delete: cascade）/ belongsTo recipient（polymorphic。DB FK なし）。

### 12-7-4. inquiry_statuses

**モデル名:** `InquiryStatus`　**テーブル名:** `inquiry_statuses`　**実装状況:** 実装済み（R4 タスク2）

**用途:** 問い合わせステータスマスタ。CustomerStatus / OrderStatus と同型だが一意性が `category` 単位のため `SystemManagedStatus` concern を流用せず個別実装。既定集合は `StatusSeeder::INQUIRY_STATUSES`。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `category` | string | NOT NULL | - | UQ（複合: category, code）, IDX（複合: category, is_active, sort_order） | 問い合わせ種別（category 内で code 一意） |
| `code` | string | NOT NULL | - | UQ（複合: category, code） | `inquiries.status` に格納されるコード |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `is_active` | boolean | NOT NULL | true | IDX（複合: category, is_active, sort_order） | 有効フラグ |
| `is_system` | boolean | NOT NULL | false | - | true=各 category の先頭値（削除・code変更禁止） |
| `label` | string | NOT NULL | - | - | 表示ラベル |
| `sort_order` | integer | NOT NULL | 0 | IDX（複合: category, is_active, sort_order） | 表示順 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

### 12-7-5. inquiry_recipient_routes

**モデル名:** `InquiryRecipientRoute`　**テーブル名:** `inquiry_recipient_routes`　**実装状況:** 実装済み（R4 タスク2）

**用途:** 種別×ステータス → 宛先グループのルーティングマスタ（`RecipientResolver.route_for`）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `category` | string | NOT NULL | - | UQ（複合: category, status_code, recipient_group_id）, IDX（複合: category, status_code） | 問い合わせ種別 |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `recipient_group_id` | uuid | NOT NULL | - | FK (→recipient_groups, on_delete: cascade), UQ（複合: category, status_code, recipient_group_id） | 宛先グループ（recipient_groups.id） |
| `status_code` | string | NOT NULL | - | UQ（複合: category, status_code, recipient_group_id）, IDX（複合: category, status_code） | ステータスコード（`inquiry_statuses.code`）。種別×ステータス → 宛先グループのルーティング（`RecipientResolver.route_for`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo recipient_groups（on_delete: cascade）。`(category, status_code, recipient_group_id)` UQ。

### 12-7-6. recipient_groups

**モデル名:** `RecipientGroup`　**テーブル名:** `recipient_groups`　**実装状況:** 実装済み（R4 タスク3）

**用途:** 宛先グループ（問い合わせルーティング・一斉通知の宛先）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `description` | text | NULL | - | - | 説明 |
| `is_active` | boolean | NOT NULL | true | IDX | 有効フラグ |
| `name` | string | NOT NULL | - | - | グループ名 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

### 12-7-7. recipient_group_members

**モデル名:** `RecipientGroupMember`　**テーブル名:** `recipient_group_members`　**実装状況:** 実装済み（R4 タスク3）

**用途:** 宛先グループのメンバー（`User` または `ProductionCompany`。polymorphic）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `recipient_group_id` | uuid | NOT NULL | - | FK (→recipient_groups, on_delete: cascade), UQ（複合: recipient_group_id, recipient_type, recipient_id）, IDX | 宛先グループ（recipient_groups.id） |
| `recipient_id` | uuid | NOT NULL | - | UQ（複合: recipient_group_id, recipient_type, recipient_id）, IDX（複合: recipient_type, recipient_id） | メンバーID（polymorphic） |
| `recipient_type` | string | NOT NULL | - | UQ（複合: recipient_group_id, recipient_type, recipient_id）, IDX（複合: recipient_type, recipient_id） | メンバークラス（`User` / `ProductionCompany`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> リレーション: belongsTo recipient_groups（on_delete: cascade）。`(recipient_group_id, recipient_type, recipient_id)` UQ。

### 12-8. 通知（R4 タスク3・4）

### 12-8-1. notification_templates

**モデル名:** `NotificationTemplate`　**テーブル名:** `notification_templates`　**実装状況:** 実装済み（R4）

**用途:** 通知テンプレート（通知用 / 問い合わせ用 / 共通）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `body` | text | NULL | - | - | 本文テンプレート |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `name` | string | NOT NULL | - | - | テンプレート名 |
| `subject` | string | NULL | - | - | 件名テンプレート |
| `template_type` | string | NOT NULL | - | IDX | `notification`（通知用）/ `inquiry`（問い合わせ用）/ `common`（共通） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

### 12-8-2. notifications

**モデル名:** `Notification`　**テーブル名:** `notifications`　**実装状況:** 実装済み（R4）

**用途:** 一斉通知（フィルタ・予約送信・宛先種別）。実送信は `NotificationDeliveryJob`。件名・本文はテンプレートからコピー（後からテンプレートを編集しても送信済み通知は変わらない）。添付は Active Storage。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `body` | text | NULL | - | - | 本文（テンプレートからコピー。ライブ参照ではない）。添付は Active Storage `attachments` |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `created_by_id` | uuid | NULL | - | FK (→users) | 作成ユーザID（users.id。TracksUser） |
| `failed_count` | integer | NOT NULL | 0 | - | 送信失敗数 |
| `filter_params` | jsonb | NOT NULL | {} | - | 宛先フィルタ（agency_group_id / agency_id / status 等） |
| `notification_template_id` | uuid | NULL | - | FK (→notification_templates, on_delete: nullify), IDX | 由来テンプレート（追跡用。nullable。R4 追加） |
| `scheduled_at` | datetime | NULL | - | IDX | 予約送信日時 |
| `sent_at` | datetime | NULL | - | - | 送信完了日時 |
| `status` | string | NOT NULL | "draft" | IDX | `draft` / `scheduled` / `sending` / `sent` / `failed` |
| `subject` | string | NULL | - | - | 件名 |
| `success_count` | integer | NOT NULL | 0 | - | 送信成功数 |
| `target_type` | string | NOT NULL | - | - | 宛先種別（`agency` / `customer`） |
| `title` | string | NOT NULL | - | - | 管理用タイトル |
| `total_count` | integer | NOT NULL | 0 | - | 宛先総数 |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |
| `updated_by_id` | uuid | NULL | - | FK (→users) | 更新ユーザID（users.id。TracksUser） |

> リレーション: belongsTo notification_templates（optional。on_delete: nullify）/ hasMany notification_recipients。

### 12-8-3. notification_recipients

**モデル名:** `NotificationRecipient`　**テーブル名:** `notification_recipients`　**実装状況:** 実装済み（R4）

**用途:** 一斉通知の宛先ごとの送信結果。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `email` | string | NULL | - | - | 送信先メールアドレス（スナップショット） |
| `error_message` | text | NULL | - | - | 失敗時のエラー |
| `notification_id` | uuid | NOT NULL | - | FK (→notifications, on_delete: cascade), IDX | 通知（notifications.id） |
| `recipient_id` | uuid | NOT NULL | - | IDX（複合: recipient_type, recipient_id） | 宛先ID（polymorphic） |
| `recipient_type` | string | NOT NULL | - | IDX（複合: recipient_type, recipient_id） | 宛先クラス |
| `sent_at` | datetime | NULL | - | - | 送信日時 |
| `status` | string | NOT NULL | "pending" | - | `pending` / `sent` / `failed` |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> リレーション: belongsTo notifications（on_delete: cascade）/ belongsTo recipient（polymorphic。DB FK なし）。

### 12-8-4. system_notifications

**モデル名:** `SystemNotification`　**テーブル名:** `system_notifications`　**実装状況:** 実装済み（R4 タスク4）

**用途:** アプリ内通知（旧 Reverb → Solid Cable / Turbo Streams でリアルタイム配信）。受信者は `User` または `Customer`（マイページ）。30日で自動 prune（`config/recurring.yml`）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `data` | jsonb | NOT NULL | {} | - | 表示用データ（jsonb） |
| `expires_at` | datetime | NOT NULL | - | IDX | 失効日時（作成から30日。`prune_expired!` を Solid Queue recurring で実行） |
| `notification_type` | string | NOT NULL | - | - | `inquiry_created` / `inquiry_replied` / `application_completed` / `notification_sent` |
| `read_at` | datetime | NULL | - | IDX（複合: recipient_type, recipient_id, read_at） | 既読日時 |
| `recipient_id` | uuid | NOT NULL | - | IDX（複合: recipient_type, recipient_id, read_at） | 受信者ID（polymorphic） |
| `recipient_type` | string | NOT NULL | - | IDX（複合: recipient_type, recipient_id, read_at） | 受信者クラス（`User` / `Customer`） |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> `created_by_id` / `updated_by_id` は持たない。

### 12-9. CSV エクスポート（R2 タスク7）

### 12-9-1. csv_exports

**モデル名:** `CsvExport`　**テーブル名:** `csv_exports`　**実装状況:** 実装済み（R2 タスク7。対象は Customer / Order のみ）

**用途:** CSV 非同期エクスポートのジョブ状態と成果物（旧 maatwebsite/excel の代替。Ruby 標準 `csv` + `CsvExportJob`）。要求者本人のみダウンロード可。複数プロファイル対応・汎用化（P4-12）と Store 対応は未実装（R6）。

| カラム名 | 型 | NULL | デフォルト | PK/FK/UQ/IDX | 説明 |
|---|---|---|---|---|---|
| `id` | uuid | NOT NULL | gen_random_uuid() | PK | 主キー |
| `created_at` | datetime | NOT NULL | - | - | 作成日時 |
| `error_message` | text | NULL | - | - | 失敗時のエラー |
| `file_data` | text | NULL | - | - | 生成した CSV 本文（DB 保持。Active Storage 未使用） |
| `requested_by_id` | uuid | NOT NULL | - | FK (→users), IDX | 要求ユーザー（users.id）。本人のみダウンロード可（Pundit スコープ迂回防止） |
| `resource_type` | string | NOT NULL | - | - | 対象（`Customer` / `Order`。許可リスト） |
| `row_count` | integer | NULL | - | - | 出力行数 |
| `status` | string | NOT NULL | "pending" | IDX | `pending` / `completed` / `failed` |
| `updated_at` | datetime | NOT NULL | - | - | 更新日時 |

> リレーション: belongsTo requested_by（users.id）。`created_by_id` / `updated_by_id` は持たない（`requested_by_id` が兼ねる）。

### 12-10. Active Storage（Rails 標準）

`active_storage_blobs` / `active_storage_attachments` / `active_storage_variant_records`（主キー uuid。`db/migrate/20260815155000_create_active_storage_tables.active_storage.rb`）。`inquiry_messages.attachments` / `notifications.attachments` の実体。列は Rails 標準のため本書では定義しない。

---

## 13. 未実装テーブル（R5/R6）

旧設計・関連設計書で言及されているが `db/schema.rb` に存在しないテーブル群。定義の正はそれぞれの設計書にあり、本書では所在と実装フェーズのみを記す（実装時に本書へ列定義を追記する）。

| テーブル（想定名） | 用途 | 定義の所在 | フェーズ | 備考 |
|---|---|---|---|---|
| `payment_transactions` | 決済トランザクション（ネットムーブ連携の状態機械。`orders.status` とは別ライフサイクル） | `payment-integration.md` §5-1 | **未実装（R5）** | 決済専用キュー・自動リトライ無効化・request spec 必須（04 R5）。`site_code` を持つ複数サイト構造（R-11） |
| `payment_transaction_logs` | 決済通信ログ（送受信・遷移） | `payment-integration.md` §5-2 | **未実装（R5）** | ret_url / cancel_url の受信記録 |
| 契約書PDF・版数管理・署名（テーブル名未定。例: `contract_documents` / `contract_signatures`） | 契約書PDF生成・版数管理・メール送付・手書き署名 | 04 R5 本文（PDF ライブラリは 03§2 で要選定） | **未実装（R5）** | Active Storage 添付を想定。`sales_representatives.pdf_*`（§7）はこの出力に使う |
| 顧客側支払情報（カードブランド・与信参照番号・カード変更日等） | 旧 `card_brand` / `credit_reference_number` / `order_code` / `card_changed_at` | 本書 §8 備考 | **未実装（R5）** | ネットムーブ会員ID（`customers.netmove_member_id`）で引き継ぐ前提（netmove-card-migration.md）。非保持非通過のため列として持たない可能性あり（要確認） |
| `customer_merges` / `customer_merge_keys` | 顧客名寄せ（統合履歴・一時統合キー） | `customer-merge-design.md` §2-1, §2-2 | **未実装（R6）** | 高リスク並行処理の request spec 必須（04 R6） |
| 集計・レポート系 / 遅延案件検知 / 自動キャンセル | 運用強化 | 04 R6 | **未実装（R6）** | 要件ごとに個別判断。集計はテーブル追加ではなくクエリ/マテビューで済む可能性あり |
| 未収情報（未回収額等） | 請求・回収状況 | 04 R2 追加タスク（旧 remaining-tasks.md 7-1） | **未実装（要否未定。R2 追加 or R6）** | `orders.sales_mgmt_slip_number` / `factor_notes` は実装済み |
| 商材別納品日（`work_completed_at` の分離） | 業務フロー差分 G-1 | `business-flow-analysis.md` | **未実装（要否未定。R5/R6）** | 現行は `orders.work_completed_at` 単一列 |
| CSV エクスポートプロファイル（`export_profiles` 等） | 複数プロファイル対応（P4-12） | `export-profile-design.md` | **未実装（R6）** | config 管理 vs DB 管理は未決 |
| `order_histories`（`operation_history` の分離） | 運用履歴の専用テーブル化 | 本書 §11 備考 | **未実装（検討中）** | 掲示板ログの実体は R4 `inquiries` に統合。過去ログは R7 アーカイブ投入 |
| `agency_emails`（通知先メールの別テーブル化） | `agencies.email_1〜5` の正規化 | 本書 §2 備考 | **未実装（検討中）** | 現時点は固定5列運用 |
| `inquiry_message_production_companies` | 問い合わせ⇄制作会社の直接紐づけ | `app/models/production_company.rb` 冒頭コメント | **未実装** | R4 では `recipient_group_members`（ProductionCompany メンバー）で代替。要確認: 直接紐づけが必要か |

---

## 14. 実装突合表（2026-08-19）

`db/schema.rb`（version 2026_08_16_150002）と本書 §1〜§11 の全カラムを機械突合（`scratchpad/diff.py`）した結果。凡例: **一致** = 列・制約が旧設計どおり / **差分** = 実装を正として本文を追従済み（内容を右列に記載）/ **追加** = 実装のみに存在（本文へ追記済み）/ **未実装** = 実装なし。

### 14-1. 旧 Column.md 記載テーブル（§1〜§11）

| § | 旧テーブル名 → 実装テーブル | モデル | 判定 | 差分・備考 |
|---|---|---|---|---|
| 1 | agency_groups | AgencyGroup | 差分（軽微） | 共通差分のみ（`created_by`→`created_by_id`、timestamps NOT NULL、ENUM→string）。`service_type` の IDX は未作成 |
| 2 | agencies | Agency | 一致 | 共通差分のみ。FK on_delete: restrict（agency_groups） |
| 3 | products | Product | 一致 | 共通差分のみ |
| 4 | plans | Plan | **差分** | 追加: `sort_order`。未実装: `initial_fee`（→product_initial_fees）/ `payment_method`（→orders）/ `plus_flag`（→product_options）/ `contract_unit` / `initial_construction`（**要確認**） |
| 5 | agency_products | AgencyProduct | 差分 | 複合PK → `id uuid` + unique index + timestamps。管理UIは未実装 |
| 6 | contract_conditions | ContractCondition | 一致 | 共通差分のみ。参照側は orders（T-3） |
| 7 | sales_representatives | SalesRepresentative | 差分 | 追加: `email` / `otp_code_digest` / `otp_code_expires_at` / `otp_attempts`（R3 メールOTP）。長さ制限（VARCHAR(50)/(100)）なし（要確認・軽微） |
| 8 | jasmin_customers → customers | Customer | **差分** | 改名: `phone_number`→`phone`。未実装: `contract_condition_id`（T-3 で orders へ）。追加: Devise 4列 + OTP 3列（R4）。`email` UQ 追加（**要確認**）。`status` 既定 `applied`（code 化）。新規採番 `C-%06d`（**要確認**: prefix） |
| 9 | jasmin_stores → stores | Store | 一致 | 改名: `jasmin_customer_id`→`customer_id` のみ |
| 10 | jasmin_orders → orders | Order | **差分** | 追加: `contract_condition_id`（NOT NULL, T-3）/ `payment_method` / `product_initial_fee_id`。`status` NOT NULL 既定 `0:受注`。`billing_password` text・ENC。改名: `jasmin_customer_id`→`customer_id`, `jasmin_store_id`→`store_id`。新規採番 `ORD{YYYY}{%04d}`（**要確認**: 形式） |
| 11 | jasmin_order_work_details → order_work_details | OrderWorkDetail | 差分 | 改名: `jasmin_order_id`→`order_id`。ID/PASS 8列を text・ENC。他は一致 |

### 14-2. 実装のみに存在するテーブル（§12 に追記済み）

| テーブル | モデル | フェーズ | 本書 |
|---|---|---|---|
| users | User | R0/R1 | §12-2-1 |
| system_permissions / system_roles / system_role_permissions / user_system_roles | SystemPermission 他 | R0 | §12-2-2〜5 |
| ip_allowlist_entries | IpAllowlistEntry | R0 | §12-2-6 |
| audit_logs | AuditLog | R0 | §12-3-1 |
| customer_statuses / order_statuses | CustomerStatus / OrderStatus | R2 | §12-4-1, 12-4-2 |
| option_groups / option_values | OptionGroup / OptionValue | R2 | §12-4-3, 12-4-4 |
| production_companies / sales_materials | ProductionCompany / SalesMaterial | R2 | §12-4-5, 12-4-6 |
| sequence_counters | SequenceCounter | R2 | §12-5-1 |
| product_initial_fees / product_options / order_options / agency_group_products | ProductInitialFee 他 | R2/R3 | §12-1 |
| form_templates / form_steps / form_fields / applications | FormTemplate 他 | R3 | §12-6 |
| inquiries / inquiry_messages / inquiry_message_recipients / inquiry_statuses / inquiry_recipient_routes / recipient_groups / recipient_group_members | Inquiry 他 | R4 | §12-7 |
| notification_templates / notifications / notification_recipients / system_notifications | NotificationTemplate 他 | R4 | §12-8 |
| csv_exports | CsvExport | R2 | §12-9-1 |
| active_storage_blobs / attachments / variant_records | （Rails 標準） | R4 | §12-10 |

### 14-3. 未実装（§13）

payment_transactions / payment_transaction_logs / 契約書・署名（R5）、customer_merges / customer_merge_keys / 集計・遅延検知 / export_profiles（R6）、未収情報・商材別納品日（要否未定）。

### 14-4. 設計方針記述の更新（本改訂で追従した項目）

| 項目 | 旧記述 | 現行実装（本書の記述） |
|---|---|---|
| 採番方式 | `count()+1`（Laravel。Column.md には明記なし） | `sequence_counters` + `SequenceCounter.next_value!`（§0, §12-5） |
| T-2 `sales_rep_code` | グローバルユニーク | 同じ（是正済み・踏襲。§7） |
| T-3 `contract_condition_id` | customers 側 | orders 側 NOT NULL（§6, §8, §10） |
| ステータス | 日本語値を直接格納（例: 申込受付） | マスタ code 参照（`customer_statuses` / `order_statuses` / `inquiry_statuses`。DB FK なし・モデル検証） |
| PII | 記述なし | 分類B を ActiveRecord::Encryption（§0, §10, §11） |
| 認証 | users のみ | users / customers / sales_representatives の3主体 + メールOTP（§0） |
| 監査 | 記述なし | `Auditable` / `AuthAuditable` → `audit_logs`（§12-3） |
| ツリー | kalnoy/nestedset 想定 | `option_values.parent_id` 自己参照（§12-4-4） |

---

*このファイルは `db/schema.rb` を正として随時追従します（旧: 実データ連携に基づき随時更新）。*
