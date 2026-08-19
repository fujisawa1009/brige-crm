# 設計（Column.md）と実装（マイグレーション）のギャップ

> 作成日: 2026-07-24
> 出典: `Column.md`（設計）× マイグレーション実カラム（実装）の全テーブル突合
> 位置づけ: **P2-4（新規カラム追加）の全容**。移行の未対応フィールド（`11` §5）の根本原因。
>
> **Rails版改訂: 2026-08-19。** 旧Laravelプロジェクト（`boilerplate-vue-env/laravel/requirements/design/legacy-research/12-schema-gap.md`）を
> brige-crm（Rails 8.1）の現行実装（`db/schema.rb`）に突合して見直し。**フェーズ対応: R2（CRM中核スキーマ）で本書のギャップは解消済み／残存分は R7 判断。**
> - **本書は歴史的記録**（2026-07-24 時点の旧 Laravel マイグレーションと Column.md の突合結果）。「customers 38カラム未実装」は旧 P2-4 → **R2 で実装済み**（04 R7 節にも記載）。
> - 調査事実（当時の設計63/実装23 等の件数）は改変しない。各ギャップに **「解消済み／残存」** を Rails版 `db/schema.rb`（2026-08-19）ベースで付記した。
> - テーブル名は決定D（prefix除去）で `customers` / `stores` / `orders` / `order_work_details`。旧名は当時の記録としてそのまま残す。

---

## 0. 結論：ギャップは jasmin_customers に集中している（初版・2026-07-24 時点）

全主要テーブルで「設計カラム vs 実装カラム」を突合した。**乖離はほぼ jasmin_customers のみ**。

| テーブル（旧名） | 設計 | 実装（当時） | 未実装（当時） | 判定（当時） | Rails版 `db/schema.rb`（2026-08-19） | 解消状況 |
|---|---|---|---|---|---|---|
| **jasmin_customers** | 63 | 23 | **約38** | 🔴 **設計の1/3しか実装されていない** | `customers` **65カラム**（Devise/OTP 列 `encrypted_password` `otp_*` `failed_attempts` `locked_at` `unlock_token` を含む） | ✅ **解消済み（R2）**。§1 の38カラムは `phone_number`→`phone` の読み替え1件を除き全て存在 |
| jasmin_stores | 21 | 18 | 0 | ✅ 実装済み | `stores` 20カラム | ✅ 一致（R2） |
| jasmin_orders | 98 | 89 | 0（差分はリレーション記述） | ✅ 実装済み | `orders` 94カラム | ✅ 一致（R2。`11` 付録A で83列を突合済み） |
| jasmin_order_work_details | 79 | 76 | 0 | ✅ 実装済み | `order_work_details` 78カラム（アカウント8列は `encrypts`） | ✅ 一致（R2） |
| agencies | 24 | 14 | 0（差分はノイズ） | ✅ 実装済み | `agencies` 16カラム（住所・電話は無し＝Q-移7 残存） | ✅ 一致（R1） |
| agency_groups | 13 | 8 | 0（ノイズ） | ✅ 実装済み | `agency_groups` 11カラム（`service_type` NOT NULL が追加） | ✅ 一致（R1） |
| sales_representatives | 18 | 16 | 0 | ✅ 実装済み | `sales_representatives` 21カラム（`email`・`otp_*` は R3 追加） | ✅ 一致（R1/R3） |
| （Rails版追加）plans | — | — | — | — | `plans` 11カラム。Rails版 Column.md §4 が設計する `contract_unit` / `initial_construction` / `initial_fee` / `payment_method` / `plus_flag` が **無い** | ⚠️ **残存**（Q-移18。`11` 168/169 の対応先。R7 着手前に要否判断） |

> **なぜ customers だけ未実装が多いか**：jasmin_customers は認証・基本情報の最小構成で先行実装され、
> **契約者情報・請求書送付先・連携コードなどの詳細フィールドが後回し**になっていた。
> basic-design §5 も「顧客詳細はフィールド定義待ち」としていた（＝W-2）。
> **W-2 は資料調査で解消**したので、今こそ Column.md 設計どおりに実装できる。
> → **Rails版では R2 の初期スキーマから Column.md 設計どおりに実装した**（03 §5「未実装機能は最初からスキーマに織り込む」）。

---

## 1. jasmin_customers 未実装カラム（P2-4 の対象・38カラム）→ **Rails版: 全て `customers` に実装済み（R2）**

Column.md §8 に設計済みだが、（当時の）マイグレーションに存在しなかった。`11` §5 で「新規」とした多くはここ。
**解消状況（2026-08-19・`db/schema.rb`）**: 下記 1-1〜1-6 の全カラムが `customers` に存在（`phone_number` のみ実装名 `phone`。Column.md 実装注記どおり）。

### 1-1. 契約者・代表者情報 — ✅ 解消済み（R2）

| カラム | 型 | 内容 | 案件238 |
|---|---|---|---|
| `contractor_name_kana` | VARCHAR(255) | 契約者名または法人名カナ | 4 |
| `representative_name` | VARCHAR(100) | 法人代表者名（氏名一括） | — |
| `representative_name_kana` | VARCHAR(100) | 法人代表者名カナ | — |
| `inventory_type` | VARCHAR(50) | 在庫区分（新規 等） | — |

### 1-2. 契約者担当者（担当者1・2） — ✅ 解消済み（R2）

| カラム | 内容 |
|---|---|
| `contact_name` / `contact_name_kana` / `contact_title` / `contact_dept_phone` | 担当者1（氏名・カナ・役職・部署電話） |
| `contact2_name` / `contact2_name_kana` / `contact2_title` / `contact2_dept_phone` | 担当者2 |
| `mobile_contact_person` | 携帯担当者名 |

### 1-3. 連絡先 — ✅ 解消済み（R2。`phone_number` は実装名 `phone`）

| カラム | 内容 |
|---|---|
| `phone_number`（実装は `phone`） / `fax_number` | 固定電話 / FAX |
| `sms_mobile_number` | SMS送信用携帯番号 |

### 1-4. ★ 請求書送付先（Q-移12 の解決） — ✅ 解消済み（R2）

| カラム | 内容 | 案件238 |
|---|---|---|
| `consolidated_billing` | 合算請求希望 | — |
| `invoice_destination` | 送付先種別（契約者住所と同一 / 設置先住所と同一 / 異なる） | 15 |
| `invoice_name` / `invoice_name_kana` | 請求書送付先名 / カナ | 16/17 |
| `invoice_postal_code` / `invoice_address` | 郵便番号 / 住所 | 18/19 |
| `invoice_phone` / `invoice_other_phone` | 日中連絡先 / その他電話 | 20/21 |

> **Q-移12 は解決**：請求書送付先は Column.md に設計済み。**新規設計は不要、実装への反映のみ**。

### 1-5. 事業情報 — ✅ 解消済み（R2。`years_in_business` は string(20)）

| カラム | 内容 |
|---|---|
| `industry` / `industry_sub` | 業種 / 小区分 |
| `num_employees` / `num_offices` / `years_in_business` | 従業員数 / 拠点数 / 営業年数 |

### 1-6. ★ 連携コード（Q-移13/14 の解決） — ✅ 解消済み（R2）

| カラム | 内容 | 備考 |
|---|---|---|
| `appointer_code` / `appointer_name` | アポインター担当者コード / 名 | **Q-移13 解決**（設計済み） |
| `confirm_staff_code` / `confirm_staff_name` | 確認担当者コード / 名 | |
| `sales_mgmt_customer_code` | 販売管理S顧客CD | **Q-移14 解決**（OBIC7連携キー・設計済み） |
| `agency_customer_code` | 代理店用顧客コード | |
| `lbc_code` | LBCコード | |
| **`netmove_member_id`** | **ネットムーブ会員ID** | **決済連携（payment-integration）の会員ID。設計済み** |
| **`netmove_registered_at`** | ネットムーブ登録日 | 同上 |

> ⭐ **決済の会員ID（netmove_member_id）が顧客テーブルに設計済み**。
> `payment-integration.md` の `member_id` パラメータ／`payment_transactions` の会員IDは
> **この顧客カラムと紐づく**。決済実装（P3-2）の前提として P2-4 で実装しておく。
> → Rails版: `customers.netmove_member_id` / `netmove_registered_at` は R2 で実装済み。**`payment_transactions` テーブル自体は R5 未着手**（04 R5・`netmove-card-migration.md`）。

---

## 2. 影響と対応

### 2-1. P2-4（新規カラム追加マイグレーション）の具体化 — ✅ 解消済み（R2）

P2-4 は「Column.md §8 の jasmin_customers 設計（63カラム）を実装に反映する」作業。
（当時）23カラム → 約38カラム追加。`11` §2/§5 の移行マッピングはこの実装後に成立する。

**実装単位（推奨・当時）**：機能グループごとにマイグレーションを分割
（契約者情報／担当者／連絡先／請求書送付先／事業情報／連携コード）。
→ Rails版では R2 の `customers` 初期マイグレーションに一括で織り込み済み（`db/schema.rb`）。`11` §2/§5 の移行マッピングは成立している。

### 2-2. 他の未確定への波及

| 論点 | 更新 | Rails版（2026-08-19） |
|---|---|---|
| Q-移12 請求書送付先 | ✅ 解決（Column.md 設計済み・P2-4 で実装） | ✅ 解消済み（`customers.invoice_*` 実装） |
| Q-移13 アポインター | ✅ 解決（`appointer_code/name` 設計済み） | ✅ 1人目は解消済み。**2人目（案件238の13/14）は対応列なし＝残存**（`11` §5） |
| Q-移14 販管顧客コード | ✅ 解決（`sales_mgmt_customer_code` 設計済み） | ✅ 解消済み |
| `11` §5 の「新規判断」 | 大半が「Column.md 設計済み → P2-4 で実装」へ変更 | ✅ 実装済み。残存は `11` 付録A の「未実装2件（168/169）＋対応先なし8件」 |

### 2-3. 契約単位・初期構築（`11` の 168/169） — ⚠️ 残存（Q-移18）

これらは jasmin_customers 設計に**見当たらない**。jasmin_orders 側 or プラン属性の可能性。
別途確認が必要（Q-移18）。
→ Rails版: Column.md §4（`plans`）に `contract_unit` / `initial_construction` として**設計は追加された**が、`db/schema.rb` の `plans` には**未反映**（`code` `monthly_fee` `name` `product_id` `is_active` `sort_order` のみ）。
案件ごとの値（スナップショット）にするなら `orders` 側、プラン属性なら `plans` 側にカラム追加が必要。**R7 着手前に要否と置き場所を判断**（04 R7 既知事項 Q-移18）。

---

## 3. 検証メモ

- 突合はカラム名の集合比較。Column.md のリレーション記述（`agencies`/`jasmin_stores` 等）や
  共通カラム（created_at 等）はノイズとして除外済み。
- jasmin_orders の差分「jasmin_order_work_details」はリレーション記述（ノイズ）。実カラムのギャップは無し。
- **customers 以外は設計と実装が一致**しており、移行マッピング（`10`/`11`）はそのまま使える。
- Rails版検証（2026-08-19）: `db/schema.rb` を Python で解析し、§1 の全カラム名を `customers` のカラム集合と突合。不一致は `phone_number`（実装 `phone`）のみ。`10`/`11` の対応表は Rails版で実装名へ更新済み。

---

## 4. development-plan への反映

| 反映先 | 内容 | Rails版フェーズ・状況 |
|---|---|---|
| P2-4 | 「jasmin_customers を Column.md 設計（63カラム）どおりに拡張。現在23実装、約38カラム追加」と明記 | R2 ✅ 実装済み |
| P3-2（決済） | `netmove_member_id`/`netmove_registered_at` を P2-4 で先行実装（決済の前提） | R2 ✅ 列は実装済み／決済本体は R5 未着手 |
| Q-移12/13/14 | 解決（設計済み・P2-4 で実装） | ✅（Q-移13 の2人目のみ残存） |
| （Rails版追加）Q-移18 | `plans.contract_unit` / `initial_construction` の schema 反映要否 | R7 着手前に判断（04 R7 既知事項） |

---

## 5. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版。全テーブル突合で設計/実装ギャップが jasmin_customers に集中（設計63/実装23）と判明。未実装38カラムを分類。請求書送付先・アポインター・販管顧客コード・netmove会員ID が設計済みと確認し Q-移12/13/14 を解決 |
| 2026-08-19 | Rails版改訂。`db/schema.rb` と再突合し、§1 の38カラムは全て `customers` に実装済み（R2）＝本書のギャップは解消済み（歴史的記録化）。残存ギャップとして `plans.contract_unit`/`initial_construction`（Q-移18）とアポインター2人目を明記 |
