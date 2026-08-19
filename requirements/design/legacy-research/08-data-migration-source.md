# データ移行元 構造調査

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/legacy-research/08-data-migration-source.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて見直し。フェーズ対応: **R7（データ移行・別プロジェクト切り出し予定・決定F）**の最重要入力。移行元 CSV の構造・件数・カラム名は不変。「新システムの対応先」列を Rails 版の実テーブル（`db/schema.rb`・R1/R2/R4 実装済み）に差し替え、旧 `organizations` / `jasmin_stores` 等の Laravel 表記を除去した。移行ツールは rake タスク／`rails runner`（Artisan の読み替え）で実装する。
>
> 出典: `20260608_リクリックジャスミンDB退避データ/CSV.zip` / 案件一覧CSV / 営業担当CSV
> 位置づけ: **P5-5（データ移行 → 04 R7）の最重要入力**。現行DB全件の構造と規模。
> ⚠️ 実データ（実名・実顧客とのやり取り）を含む。**移行設計時のみ扱い、個票を転記しない**。

---

## 1. 移行元データの全体像（現行ジャスミンDB退避）

`CSV.zip`（29MB・9ファイル）＝現行ジャスミンのマスタ＋トランザクションの全件退避。

| テーブル（CSV） | 件数 | 新システムの対応先（brige-crm・2026-08-19 突合） |
|---|---|---|
| グループ一覧_bridge | 36 | `agency_groups`（`AgencyGroup`。R1 実装済み。旧 `organizations` テーブルは brige-crm に存在しない） |
| 代理店一覧_bridge | 302 | `agencies`（`Agency`。R1 実装済み。⚠️ **住所・電話カラム無し** = Q-移7） |
| 営業担当者一覧_bridge | 109 | `sales_representatives`（`SalesRepresentative`。R1 実装済み。`sales_rep_code` グローバル一意 = T-2 是正済み） |
| 施工担当者一覧_bridge | 36 | **対応先なし**（新スキーマに施工担当者の概念が無い = DM-7・R7 持ち越し） |
| 店舗一覧_bridge | 1,247 | `stores`（`Store`。旧 `jasmin_stores`。R2 実装済み。`customer_id` 必須のため顧客との紐づけ解決が前提） |
| 店舗一覧_bridge_plus | 2,180 | `stores`（同上・BridgePlus分） |
| 掲示板_bridge | **77,981** | `inquiries` / `inquiry_messages`（R4 `Inquiry` 統合・決定 D-11）または参照アーカイブ（Q-C 決定済み: 参照アーカイブ） |
| 掲示板一覧_bridge_plus | **342,594** | 同上 |

> **掲示板が桁違いに大きい（合計42万件超）。** これが移行の最大の塊。
> 掲示板を新システムでどう実装するか（Q-C）が、**移行の規模とコストを直接左右する**。
> → 04 R7: **掲示板42万件は参照アーカイブ（Q-C 決定済み）**。R4 の `Inquiry`（category 4種 × `InquiryStatus`）に投入する場合は
> `10-migration-mapping.md` §8 のマッピングに従う。投稿者名の名寄せ（`manager` / `contributor` 等の手入力文字列 → `users` / `sales_representatives` の UUID）は
> `../name-matching-process.md` を一次資料とする（04 R7 追記）。

### 別途の案件・組織CSV（2026-05-11 / 05-13 出力）

| CSV | 件数 | 内容 | brige-crm 対応先 |
|---|---|---|---|
| all_bridge | 1,206 | Bridge案件（受注238カラム相当） | `customers` / `stores` / `orders` / `order_work_details`（R2 実装済み。列対応は `11-order-field-mapping.md`） |
| all_bridge_plus | 2,092 | BridgePlus案件 | 同上 |
| BP_all_resp | 310 | 営業担当者（BridgePlus） | `sales_representatives` |
| BP_all_shop | 129 | 店舗（代理店・BridgePlus） | `agencies`（「店舗」と呼ばれているが代理店） |
| BP_all_group | 122 | 代理店グループ（BridgePlus） | `agency_groups` |

> Bridge と BridgePlus で件数が異なる（営業担当 109 vs 310 等）＝**出力時期・系統で差**。
> 移行時に「どの断面を正とするか」の確定が必要。

---

## 2. 現行スキーマのカラム命名（新スキーマとの差異）

現行は**英語スネークケースだが独自命名**。新スキーマ（Column.md）と機械的に対応しない。

### 掲示板（bbs_*）34列

```
bbs_id, commodity_type, target_id, after_flg, latest_flg, parent_bbs_id,
bbs_status, bbs_after_status, bbs_ac_call_status, bbs_creation_status,
bbs_category_1, bbs_category_2, bbs_category_3, bbs_category_sw,
receiving_desc, manager, contributor, f_manager, f_contributor,
n_manager, n_contributor, title, body, make_type, admin_id,
first_insert_bbs_status, first_insert_bbs_after_status,
first_insert_bbs_ac_call_status, first_insert_bbs_creation_status,
first_insert_bbs_category_ac_call, first_insert_manager,
first_insert_f_manager, first_insert_n_manager, first_insert_n_contributor
```

- `commodity_type` = 商材種別（Bridge/BridgePlus判別）
- `bbs_status` / `bbs_after_status` / `bbs_ac_call_status` / `bbs_creation_status`
  = **掲示板種別ごとのステータスが1レコードに横持ち**（後確・アフター・検収コール・制作）
  → `05-legacy-spec-fields.md` の4掲示板と対応
- `bbs_category_1/2/3` = アフター掲示板のカテゴリ（05 §5-2 と一致）
- `parent_bbs_id` = 返信のスレッド構造 / `latest_flg` = 最新版
- `manager` / `contributor` / `n_manager`（次回対応者）= 対応者・投稿者（手入力文字列）
- `first_insert_*` = 初回投入時のステータス・対応者を保持

### 店舗（l_store_place_cd, facility_*）24列

```
l_store_place_cd, facility_name, facility_name_kana, post_1, post_2,
prefecture_id, address_1/2/3, tel_1/2/3, fax_1/2/3,
space_open_time, space_open_time_min, space_close_time, space_close_time_min,
space_open_time2 … space_close_time2_min, space_regular_holiday
```

- 住所・電話・営業時間が**細かく分割**（post_1/2、tel_1/2/3、time/min×2枠）。
  新スキーマは統合形が多いため、**結合ルールが必要**（→ `09` C-2）。
  brige-crm の `stores`（R2 実装済み）: `postal_code`(8) / `prefecture`(20) / `city`(50) / `town`(100) / `address_detail`(200) /
  `phone_number`(20) / `fax_number`(20) / `business_hours_1`(50) / `business_hours_2`(50) / `regular_holiday`(100) /
  `store_name` / `store_name_kana` / `store_code`(20)。`address_1/2/3` → `city` / `town` / `address_detail` の 1:1 対応可（`00` 検証パス9）。
  `prefecture_id`（数値）→ `prefecture`（文字列）の変換表が必要。

### 代理店・グループ

- 数値コード（970393等）＋名称＋親子コード＋メールアドレス
- グループ「NEXTパートナー（ショット）」等。半角カナ表記あり → 正規化が必要
- brige-crm 対応先（R1 実装済み）: `agency_groups.group_code`（一意）/ `name` / `contact_email` / `service_type`（必須）、
  `agencies.agency_code`（一意）/ `agency_group_id`（必須）/ `name` / `contact_person` / `email_1〜5`。
  ⚠️ `agencies` に**住所・電話カラムが無い**（Q-移7。旧CSVの住所・電話をどこに載せるか未決）。
  `sales_representatives` は `pdf_*`（PDF出力用の店舗名・住所・電話・FAX）を持つが代理店本体の住所ではない。

---

## 3. 移行設計への示唆

| # | 論点 | 対応 | brige-crm 状態（2026-08-19） |
|---|---|---|---|
| DM-1 | **掲示板42万件の移行方針** | Q-C（掲示板の実装方針）が前提。全件移行 or 直近のみ or アーカイブ別置き | **Q-C 決定済み: 参照アーカイブ**（04 R7）。`Inquiry` への投入範囲は R7 設計で確定 |
| DM-2 | カラム命名のマッピング表 | 現行(bbs_*/facility_*/…) → 新(Column.md) の対応表を作る（`release-readiness.md` B-3 / `09`） | `10-migration-mapping.md` / `11-order-field-mapping.md` で作成済み。R2 実装済みスキーマと致命的矛盾なし（review-05 §6） |
| DM-3 | 分割カラムの結合 | 住所(post_1+2)・電話(tel_1/2/3)・営業時間(time+min)の結合ルール | `09` C-2。`stores` の受け皿は上記 §2 のとおり |
| DM-4 | 半角カナ・表記ゆれの正規化 | グループ・代理店名のクレンジング | `09`。R7 |
| DM-5 | Bridge/BridgePlus の統合 | `commodity_type` で判別。件数差の断面確定（§1 注記） | `products` マスタ＋`orders.bridge_migration*` 列（R2）で受ける。断面確定は R7 の業務判断 |
| DM-6 | ステータスの旧→新マッピング | 03の統廃合（受注削除・3ステータス統合）を移行時に適用 | `order_statuses` は最小セットのみ投入済み（`StatusSeeder`）。⚠️ 既定値 `0:受注` と精査「受注削除」の食い違い（`03` §3 注記）を R7 マッピング前に決定 |
| DM-7 | 施工担当者の扱い | 新スキーマに対応概念なし。要否確認 | **未決・R7 持ち越し**（04 R7 既知の未決事項。R1 組織領域の要否確認） |
| DM-8 | 採番の引き継ぎ | 顧客番号 FTW / 案件番号 BP の連番をどう継続するか | 新採番は `SequenceCounter`（`C-%06d` / `ORD{年}{連番4桁}` / `INQ-%06d`。R2 実装済み・UPSERT でアトミック）。旧番号の保持列は `orders.serial_id`（Column.md §10: 「シリアルID＝旧システムの案件番号と同値・レガシー保持用」）と `orders.bridge_migration_order_number`（Bridge 移行案件番号）が実装済み。旧 FTW 顧客番号（会員番号）の専用保持列は無い（`customers.agency_customer_code` は代理店用顧客コードで別物）→ 移行時に `customer_number` へ旧番号をそのまま入れるか新採番するかを R7 で決定し、新採番なら移行後の連番開始値を `sequence_counters` に seed する |

---

## 4. 移行のマイルストーン位置づけ

`release-readiness.md` B（データ移行）の具体化：

```
B-1 現行スキーマ把握   ← 本ノートで着手済み（構造・件数を把握）
B-3 マッピング定義     ← 09（整形設計）/ 10 / 11 で具体化
B-7 移行リハーサル     ← 掲示板42万件の性能確認を含む
B-9 カットオーバー     ← Bridge/BridgePlus 両系統・断面確定
```

> **B-1（現行スキーマ把握）は本調査で実質着手できた。** M-2 は解消。
> 整形（ETL）の詳細は `09-data-cleansing.md`。
>
> **Rails 版での位置づけ（04 R7）**: データ移行は決定 F により別フェーズ（別プロジェクト切り出し予定）。
> 移行ツールは rake タスク／`rails runner`（PostgreSQL への投入。UUID 主キーのため旧数値IDは対応表で保持）で実装し、
> R2 実装済みスキーマとのマッピング整合は「R2 スキーマ設計時点から常時確認」の原則で維持する。
> R7 に持ち越す既知の未決事項: **Q-移7**（`agencies` 住所・電話）／**Q-移15**（月額料金スナップショット）／
> **Q-移18**（契約単位168・初期構築169 の対応先）／**DM-7**（施工担当者）／DM-6 の `0:受注` 既定値／DM-8 の旧番号保持列。

---

## 5. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版。現行DB退避データ9ファイルの構造・件数を把握。掲示板42万件が移行の最大塊。マッピング論点 DM-1〜8 を抽出 |
| 2026-07-24 | 検証で件数の二重減算を修正（代理店302・営業109・施工36・店舗1247/2180） |
| 2026-08-19 | **Rails版改訂**（brige-crm）。対応先を Rails 実テーブル（`agency_groups` / `agencies` / `sales_representatives` / `stores` / `inquiries`）へ差し替え（旧 `organizations` / `jasmin_stores` 表記除去）、`stores`・`agencies` の実カラムと Q-移7 を注記、DM-1〜8 に brige-crm 状態列を追加（Q-C 決定済み、`SequenceCounter` 採番、DM-6/7/8 の R7 持ち越し）、R7 位置づけ（決定F・rake タスク）を追記 |
