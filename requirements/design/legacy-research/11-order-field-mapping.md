# 案件238フィールド → 新スキーマ マッピング（DM-2 §7）

> 作成日: 2026-07-24
> 出典: `03.機能非機能要件/出力_受注フィールド一覧.xlsx`（238フィールド）× 新スキーマ実カラム
> 位置づけ: `10-migration-mapping.md` §7 の本体。**移行の紐づけの起点**（顧客・店舗・組織を案件から辿る）。
> ⚠️ 実データ（PII）を含む。値は転記せず、構造・対応のみ記載。
>
> **Rails版改訂: 2026-08-19。** 旧Laravelプロジェクト（`boilerplate-vue-env/laravel/requirements/design/legacy-research/11-order-field-mapping.md`）を
> brige-crm（Rails 8.1）の現行実装（`db/schema.rb`）・03/04 の決定に合わせて見直し。**フェーズ対応: R7（データ移行。旧 P5-5 相当）／マッピング先は R2 実装済みスキーマ。**
> - 調査事実（旧システムの238フィールド・件数・CSV実測）は改変していない。改訂したのは「新システムでの対応先」の表記のみ:
>   `jasmin_customers` → `customers`、`jasmin_orders` → `orders`、`jasmin_order_work_details` → `order_work_details`、`jasmin_stores` → `stores`（決定D・prefix除去）、
>   `organizations.id` → `agency_groups.id` / `agencies.id`（Rails版に organizations テーブルは無く、代理店G/代理店が各自 UUID を持つ）。
> - 各対応表に **「実装状況」列を追加**（`db/schema.rb` と機械突合。2026-08-19時点）。全238フィールドの逐一判定は **付録A** に掲載。
> - 旧記述の「P2-4 で実装すれば解決」は **R2 で実装済み**（`customers` は 65カラム。§5 参照）。残る未実装は §5 / 付録A の通り。

---

## 0. 結論：新スキーマは238フィールドを高い網羅性でカバー

案件238フィールドを4テーブル（customers / orders / order_work_details / stores）＋
参照解決に振り分けた結果、**大半が実装済みカラムに対応**していた（Column.md の設計品質は高い）。
未対応（新規カラム要否）は §5 に集約。

| 振り分け先 | 概数（初版） | 主な内容 |
|---|---|---|
| 参照解決（FK） | ~14 | グループCD/販売店CD/営業担当CD/アポインター |
| customers | ~25 | 契約者情報・請求書送付先・契約者住所 |
| orders | ~90 | 日付・ステータス・決済・信販・Bridge移行・サイテーション・外部リンク・Google広告 |
| order_work_details | ~90 | システムアカウント・GBP・Instagram・属性1-11・キーワード・店舗詳細 |
| stores | ~10 | ご利用施設名称・店舗住所・営業時間 |
| 新規/要確認 | ~9 | §5 |

**Rails版突合結果（2026-08-19・`db/schema.rb` と全238フィールドを機械突合。付録A）**:

| 実装状況 | 件数 | 内訳 |
|---|---|---|
| 実装済みカラムに対応（R2） | **219** | orders 84 / order_work_details 75 / customers 42 / stores 17 / plans 1（61 月額料金＝`plans.monthly_fee` 参照導出）。うち22件は同一情報の重複列（電子契約作業項目側の再掲。移行時に正となる列を決める） |
| 参照解決（FK。R1/R2 実装済みマスタへ名寄せ） | **9** | 5-10（グループ/販売店/営業担当のCD・名）・60/100（プラン）・62（初期費用） |
| 未実装（Column.md 設計済み・schema 未反映） | **2** | 168 契約単位→`plans.contract_unit`、169 初期構築→`plans.initial_construction`（Q-移18） |
| 対応先なし・要確認 | **8** | 13/14 アポインター2人目、79 店舗メールアドレス、120 担当者の生年月日、132-134（営業担当/販売店/担当。用途不明）、233 ID |

→ 移行先が未実装のフィールドは **計10件（238中）**。いずれも移行対象とするか否か（要否）が先に決まる論点で、**新規機能（R5/R6）に依存するものは無い**。R7 着手前に要否判断（§5・§6）。

---

## 1. 参照解決（FK）— 移行の紐づけの起点

案件CSVは**組織・営業担当を「CD（コード）」で持つ**。移行時に**新 agency_groups / agencies /
sales_representatives の UUID へ名寄せ**する（Rails版は organizations テーブルを持たず、`agency_groups.id` / `agencies.id` が直接 UUID 主キー）。これが `10` の Q-移8/9（店舗→顧客、営業→代理店の
紐づけ復元）を解く鍵。

| 現行フィールド | 解決先 | 名寄せキー | 実装状況（2026-08-19） |
|---|---|---|---|
| 5 グループCD / 6 グループ名 | `agency_groups.group_code` → `agency_groups.id` | group_code | 実装済み（R1。`group_code` UNIQUE） |
| 7 販売店CD / 8 販売店名 | `agencies.agency_code` → `agencies.id` | agency_code | 実装済み（R1。`agency_code` UNIQUE） |
| 9 営業担当者コード / 10 営業担当者名 | `sales_representatives.sales_rep_code` → `sales_representatives.id` | sales_rep_code | 実装済み（R1。T-2 是正でグローバルUNIQUE） |
| 11-14 アポインター担当者コード/名（×2） | 11/12 → `customers.appointer_code` / `appointer_name`。**13/14（2人目）は対応列なし**（§5） | — | 11/12 実装済み（R2）／13/14 要確認 |
| 1 顧客番号（FTW） | `customers.customer_number` | 顧客の起点 | 実装済み（R2。UNIQUE・`SequenceCounter` 採番。**移行時は旧番号を保持し採番カウンタを繰り上げる**） |
| 2 案件番号（BP） | `orders.order_number` | 案件の起点 | 実装済み（R2。UNIQUE・同上） |

> **移行順序**：組織（グループ→代理店→営業担当）→ 顧客 → 店舗 → 案件、の順で投入し、
> 案件は上記CDを新IDへ解決してFKを張る。案件CSVが**店舗・顧客の紐づけを供給**する（`10` §5/§7）。
> **Rails版注記**: `stores.customer_id` / `orders.customer_id` / `orders.agency_id` / `orders.contract_condition_id` は **NOT NULL**（`db/schema.rb`）。
> 店舗は顧客紐づけが解決するまで投入できず、案件は契約条件（`contract_conditions`。R1 実装済み・代理店単位）を先に用意する必要がある（旧システムに対応する概念が無いため **移行用の既定契約条件を代理店ごとに生成する**方針を R7 で決める。要確認）。

---

## 2. customers（契約者情報）

| 現行フィールド | 新カラム（`customers`） | 実装状況（2026-08-19） |
|---|---|---|
| 1 顧客番号 | `customer_number` | 実装済み（R2） |
| 3 契約者名または法人名 / 4 カナ | `name` / `contractor_name_kana`（初版の `name_kana` は実装名に読み替え） | 実装済み（R2） |
| 80 契約者区分 | `applicant_type` | 実装済み（R2） |
| 149 メールアドレス / 78 管理者メールアドレス | `email`（複数は要検討。**実装は UNIQUE 制約あり**＝同一メールの顧客が複数いると投入不可。R7 で重複時の扱いを決める） | 実装済み（R2）／重複対応は要確認 |
| 84 携帯電話番号 / 83 連絡先固定電話番号 | `mobile_phone` / `phone` | 実装済み（R2） |
| 97 契約者郵便番号 / 98 契約者住所 | `postal_code` / `prefecture`+`city`+`town`+`address_detail`（**分割**） | 実装済み（R2）／パース規則は Q-移17 |
| 59 顧客ステータス | `status`（`03` の統廃合マッピング適用。実装は `customer_statuses.code` をマスタ参照。既定 `applied`） | 実装済み（R2）／コード変換表は R7 |
| 33 受注日（申込日） | `applied_at` | 実装済み（R2） |
| 36 契約開始日 | `contracted_at` | 実装済み（R2） |
| 11/12 アポインター、15-21 請求書送付先、51 販管顧客コード、71/72 業種、85/86/119/121 担当者、102/103・173-176 代表者、177-184 電話・住所分割 | `appointer_*` / `invoice_*` / `sales_mgmt_customer_code` / `industry(_sub)` / `contact_*` / `representative_name(_kana)` / `phone` / `prefecture`〜`address_detail` | 実装済み（R2。旧 P2-4 の38カラム追加は完了。詳細は付録A） |

> ⚠️ 契約者住所（98）は現行が1フィールド、新は4分割。**住所パース**が必要（`09` C-2 の逆方向）。
> 契約者住所の分割元があるか（案件CSVに `契約者郵便番号`/`契約者住所` のみ）要確認。

---

## 3. orders（受注・契約管理）

大半が実装済み。主要対応（✅=実装済みカラムあり）。**Rails版突合（2026-08-19）: 本節に挙げた83カラムは全て `db/schema.rb` の `orders` に存在**（`orders` は94カラム）。

| 群 | 現行フィールド → 新カラム（`orders`） | 実装状況 |
|---|---|---|
| 日付 | 33受注日→`ordered_at` / 36契約開始日→`contract_start_date` / 37契約書送付日→`contract_sent_at` / 38発注日→`issued_at` / 39アカウント発行日→`account_issued_at` / 40作業完了日→`work_completed_at`(⚠️G-1 商材別要分離) / 43検収完了日→`inspection_call_completed_at` / 44計上月→`accounting_month` / 45決済回収日→`payment_collected_at` / 46決済書類確認日→`payment_doc_confirmed_at` / 56キャンセル日→`cancelled_at` / 57解約日→`terminated_at` | 実装済み（R2）。40 の商材別分離（G-1）は未対応（R5/R6 判断） |
| ステータス | 59顧客ステータス→`status` / 172契約ステータス→`contract_status` | 実装済み（R2）。`status` は `order_statuses.code` 参照（既定 `0:受注`）・旧→新コード変換は R7 |
| 確認コール | 34架電担当→`confirm_call_staff_name` / 35詳細→`confirm_call_notes` / 81連絡希望日→`confirm_call_preferred_date` / 82架電時間→`confirm_call_time` / 87担当者名→`confirm_call_contact_name` / 90備考→`confirm_call_remarks` | 実装済み（R2） |
| 検収コール | 41NG時間帯→`inspection_call_ng_time` / 42履歴→`inspection_call_history` | 実装済み（R2） |
| 同意書 | 47高齢者同意書→`elderly_consent` / 48回収日→`elderly_consent_collected_at` / 49業務権限証明書→`business_auth_doc` / 50回収日→`business_auth_doc_collected_at` / 91事業証明→`business_proof` | 実装済み（R2） |
| 電子契約同意 | 92同意状況→`consent_status` / 93代表者年齢→`consent_rep_age` / 94担当者年齢→`consent_contact_age` / 89用紙送付先→`paper_address_note` | 実装済み（R2） |
| 決済・請求 | 88お支払方法→`payment_method` / 52販管売上伝票番号→`sales_mgmt_slip_number` / 53ファクター回収備考→`factor_notes` / 54おまとめ請求→`bundled_billing` / 55おまとめ先案件番号→`bundle_target_order_number` / 62初期費用→`product_initial_fee_id`(参照) | 実装済み（R2）。決済トランザクション本体（`payment_transactions`）は R5 未着手 |
| プラン | 60プラン名/100プラン→`plan_id`(参照) / 61月額料金→（plan紐づけ・保存要否） / 168契約単位→**新規?** / 169初期構築→**新規?** / 170-171 Plus/Plus申込→`plus_applied` | `plan_id`/`plus_applied` 実装済み（R2）。**168/169 は `plans.contract_unit`/`initial_construction` として Column.md 設計済みだが schema 未反映＝未実装**（Q-移18）。61 は `plans.monthly_fee` 参照（スナップショット要否 Q-移15） |
| 会員系 | 31会員管理ID→`member_id` / 32請求パスワード→`billing_password` / 95MEO施策管理番号→`meo_mgmt_number` / 96トスアップCD→`toss_up_code` / 99シリアルID→`serial_id` / 63システムアカウントID→（work_detailsにもあり要整理） | 実装済み（R2）。`billing_password` は `encrypts`（暗号化）。63 の正の格納先は Q-移16 |
| Bridge移行 | 73Bridge移行→`bridge_migration` / 74案件番号→`bridge_migration_order_number` / 75Bridge計上月→`bridge_accounting_month` / 76販売店名→`bridge_agency_name` / 77営業担当者名→`bridge_sales_rep_name` | 実装済み（R2） |
| サイテーション | 185申込→`citation_applied` / 189申込数→`citation_count` / 200既存シリアル→`citation_existing_serial` / 205国内プラン→`domestic_citation_plan` / 217プラン→`citation_plan` | 実装済み（R2） |
| CMS | 186 Sプラン→`s_plan_cms` / 187 Owlet→`owlet_cms` / 188 Onerank→`onerank_cms` | 実装済み（R2） |
| 外部リンク | 197申込→`external_link_applied` / 198申込数→`external_link_count` / 199型→`external_link_type` | 実装済み（R2） |
| 多言語・MEO | 201多言語対策→`gbp_multilingual` / 202言語選択→`language_selection` / 203MEO既存シリアル→`meo_existing_serial` / 204infoBiz→`infobiz_applied` / 228MEOプレミアム→`meo_premium_applied` | 実装済み（R2） |
| Google広告・口コミ | 229申込→`google_ads_applied` / 230申込数→`google_ads_count` / 231口コミ表示→`google_review_display` / 232見出し→`review_heading` / 234予約システム→`reservation_system` / 235ポータル掲載→`portal_site_applied` | 実装済み（R2） |
| 信販（Bridge側のみ） | 218信販区分→`finance_division` / 219設置先→`finance_installer` / 220郵便→`finance_postal_code` / 221都道府県→`finance_prefecture` / 222市区町村→`finance_city` / 223町名→`finance_town` / 224番地→`finance_address_detail` / 225ビル→`finance_building` / 226電話→`finance_phone` | 実装済み（R2） |
| 備考 | 190備考→`remarks` / 227共有事項→`shared_notes` / 58解約理由→`termination_reason` | 実装済み（R2） |

---

## 4. order_work_details（作業項目・GBP・属性）

電子契約作業項目（`05` §4）と対応。属性1-11・キーワードを含む。主要対応（✅）。**Rails版突合（2026-08-19）: 本節の全カラムは `db/schema.rb` の `order_work_details`（78カラム）に存在。`orders` と 1:1（`order_id` UNIQUE）。**
アカウント系8列（`system_account_id/pass` `google_account_id/pass` `instagram_id/pass` `facebook_id/pass`）は `ActiveRecord::Encryption`（`encrypts`）で暗号化保存＝**移行投入は必ず ActiveRecord 経由で行う**（生SQL/COPY で入れると復号不能）。

| 群 | 現行 → 新カラム（`order_work_details`） | 実装状況 |
|---|---|---|
| アカウント | 63/166システムアカウントID/PASS→`system_account_id`/`system_account_pass` / 236/237 GoogleアカウントID/PASS→`google_account_id`/`google_account_pass` | 実装済み（R2・暗号化列） |
| Instagram/Facebook | 65Instagramアカウント→`instagram_account` / 66/67 ID/PASS→`instagram_id`/`instagram_pass` / 191ログイン確認→`instagram_login_confirmed` / 126/127 FacebookID/PASS→`facebook_id`/`facebook_pass` / 143Facebook所持→`has_facebook` / 144Instagram所持→`has_instagram` | 実装済み（R2・暗号化列） |
| GBP | 68/146 GBP権限/オーナー権限→`gbp_permission`/`gbp_owner_permission` / 147所有者名→`gbp_owner_name` / 148連絡先→`gbp_owner_contact` / 192権限付与→`gbp_owner_permission_granted` / 123 GBP URL→`gbp_url` / 108サイトURL→`gbp_site_url` / 238既存GBP削除新規→`gbp_delete_new` / 145 Google所持→`has_google_business` | 実装済み（R2） |
| キーワード | 122地域＋業種→`keyword_region_industry` / 206都道府県→`keyword_prefecture` / 207市町村→`keyword_city` / 208-210エリア1-3→`keyword_area_1/2/3` / 211メイン→`keyword_industry_main` / 212-215サブ1-4→`keyword_industry_sub1〜4` / 216備考→`keyword_remarks` / 140ビジネスカテゴリー→`business_category_keyword` / 141業種キーワード→`industry_keyword` | 実装済み（R2） |
| 店舗詳細 | 150業態→`business_type` / 116開業日→`opening_date` / 117従業員数→`num_employees` / 118資本金→`capital` / 111最寄駅→`nearest_station` / 112道順→`directions` / 113駐車場→`parking` / 114台数→`parking_capacity` / 128バリアフリー→`barrier_free` / 129Wi-Fi→`wifi_available` / 115利用可能カード→`accepted_cards` / 130ロゴ写真→`logo_photo` / 138店舗数→`num_stores` / 139ビジネスアカウント名→`business_account_name` | 実装済み（R2） |
| 営業時間詳細 | 162ランチ→`lunch_hours` / 163ディナー→`dinner_hours` / 164入店可能→`available_from` / 165注文可能→`order_time` | 実装済み（R2） |
| 属性 | 151-161 属性1-11→`attribute_1〜11` | 実装済み（R2） |
| 連絡希望 | 193時間帯→`contact_easy_time` / 194その他→`contact_easy_time_note` / 195曜日→`contact_easy_day` / 196その他→`contact_easy_day_note` | 実装済み（R2） |
| その他 | 131ヒアリングシステム→`hearing_system` / 142参考サイトURL→`reference_url` / 69履歴記載枠→`operation_history` / 70作業進行備考→`work_progress_notes` / 190備考→（`orders.remarks`と重複注意） | 実装済み（R2） |

---

## 5. 新規カラム要否・要確認（未対応フィールド）

> ⭐ **重要な訂正（初版 2026-07-24）**：下記の多くは「新規」ではなく **Column.md に設計済みだが未実装**だった
> （`12-schema-gap.md` で判明。旧 jasmin_customers は設計63/実装23）。**P2-4 で実装すれば解決**。
> **Rails版追記（2026-08-19）**: 旧 P2-4 相当は **R2 で実装済み**（`customers` 65カラム。`db/schema.rb`）。下表の「対応」列を現況に更新。

| 現行フィールド | 状況 | 対応（Rails版 2026-08-19 現況） |
|---|---|---|
| 11-12 アポインター担当者コード/名 | Column.md 設計済み（`appointer_code`/`appointer_name`） | ✅ **実装済み（R2）**（Q-移13 解決） |
| 13-14 アポインター担当者コード2/名2 | 実装・設計とも1組のみ | ⚠️ **対応列なし**。2人目を移行するか要確認（Q-移13 補足。R7 判断） |
| 51 販管顧客コード | Column.md 設計済み（`sales_mgmt_customer_code`） | ✅ **実装済み（R2）**（Q-移14 解決） |
| 15-21 請求書送付先（名/カナ/郵便/住所/電話） | Column.md 設計済み（`invoice_*`・`consolidated_billing`） | ✅ **実装済み（R2）**（Q-移12 解決） |
| 決済会員ID | Column.md 設計済み（`netmove_member_id`/`netmove_registered_at`） | ✅ **実装済み（R2）**。取り込み ETL 枠は R5/R7（`netmove-card-migration.md`・04 R5） |
| 168 契約単位 / 169 初期構築 | Column.md §4 で **`plans.contract_unit` / `plans.initial_construction` として設計済み**（Rails版 Column.md）だが `db/schema.rb` の `plans` に無い | ⚠️ **未実装（設計済み・schema 未反映）**。案件側スナップショットにするかプラン属性にするか含め要確認（Q-移18。R7 着手前に判断） |
| 233 ID / 132-134 ヒアリングシステムの担当 | 用途不明 | ⚠️ 対応先なし。要確認（R7） |
| 79 店舗メールアドレス | `stores` にメール列なし（Column.md 設計にも無し） | ⚠️ 対応先なし。要否確認（R7。必要なら `stores` にカラム追加） |
| 120 担当者の生年月日 | 対応列なし | ⚠️ 要否確認（R7。同意時年齢 93/94 は `orders` に実装済み） |
| 61 月額料金 | plan紐づけで導出可（`plans.monthly_fee` 実装済み） | スナップショット保存の要否（Q-移15。旧プラン保持と連動。R5 契約・請求と関連） |

> **請求書送付先（15-21）は Column.md §8 に設計済み**（`invoice_destination` 等）。
> 初版時点では実装マイグレーションに無いだけだった。**Rails版では R2 で実装済み**（`12-schema-gap.md` §1-4 は解消済み）。

---

## 6. マッピングから生じた確認事項

| # | 論点 |
|---|---|
| Q-移12 | 請求書送付先情報（名・カナ・郵便・住所・電話）の格納先（新カラム or 別テーブル） → **解決（R2 で `customers.invoice_*` 実装済み）** |
| Q-移13 | アポインター担当者（コード/名×2）を移行するか。するなら格納先 → 1人目は解決（`appointer_code/name`）。**2人目（13/14）の要否は残存** |
| Q-移14 | 販管顧客コード（OBIC7連携キー）の要否 → **解決（`sales_mgmt_customer_code` 実装済み）** |
| Q-移15 | 月額料金を契約時点でスナップショット保存するか（旧プラン保持と連動） → **残存**（R5/R7） |
| Q-移16 | システムアカウントID/PASS が orders と work_details の両方に登場。正の格納先を1つに → Rails版実装では **`order_work_details` のみ**に列がある（`orders` 側に無し）＝実装上は解決。移行は work_details へ |
| Q-移17 | 契約者住所（1フィールド）→ 顧客4分割カラムへのパース（分割元の有無） → **残存**（R7。180-184 の分割列が埋まっている行はそちらを優先） |
| Q-移18 | 契約単位（168）/初期構築（169）の対応先 → **残存**（Column.md 設計は `plans` 側だが schema 未反映） |

---

## 6-2. 案件CSVの実ヘッダ検証（済）

案件CSV `all_bridge_plus` を実測した結果：

| 項目 | 結果 |
|---|---|
| 文字コード | **CP932（SJIS）** ※DB退避CSV（UTF-8）と異なる → `09` C-7 に反映 |
| ヘッダ | **日本語見出し**（受注フィールド一覧xlsx の238と**完全一致**。先頭「顧客番号」〜末尾「既存GBP削除し、新規作成希望」） |
| 列数 | 239（**238フィールド＋末尾に空列1**＝トレーリングカンマ。空列は無視） |

→ 案件CSVは日本語ヘッダで238フィールドと1:1対応するため、本ノート §1〜5 の対応表が**そのまま使える**
（英語カラムへの読み替えは不要だった）。

## 7. 次段階

- ~~請求書送付先（15-21）の設計判断（Q-移12）→ basic-design / Column.md へ反映~~ ✅ R2 実装済み
- ~~システムアカウントID/PASS の二重定義解消（Q-移16）~~ ✅ 実装は `order_work_details` 側のみ
- 契約者住所（98）→ 顧客4分割カラムへのパース可否（Q-移17）をサンプルで確認（R7）
- 168/169（Q-移18）・13/14・79・120・132-134・233 の要否判断（R7 着手前。付録A「対応先なし／未実装」10件）
- 移行 ETL 実装（rake タスク／`rails runner`・ActiveRecord 経由。`09` §6-2 Rails版）は R7 で着手

---

## 8. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版。案件238フィールドを4テーブル＋参照解決へ振り分け。実装済みカラムとの対応を整理し、新規要否（請求書送付先・アポインター・販管顧客コード等）と確認事項 Q-移12〜17 を抽出 |
| 2026-08-19 | Rails版改訂。テーブル名を実装名（`customers`/`orders`/`order_work_details`/`stores`、`agency_groups.id`/`agencies.id`）へ更新。`db/schema.rb` と全238フィールドを機械突合し「実装状況」列と付録A（全238行）を追加。実装済み 219＋FK 9／未実装 2（168/169）／対応先なし 8 を確定。Q-移12/14/16 解決、Q-移13 は2人目のみ残存 |

---

## 付録A. 全238フィールド 実装状況一覧（2026-08-19・`db/schema.rb` 機械突合）

> 生成方法: 受注フィールド一覧（238ヘッダ）× 本書 §1〜5 の対応 × `db/schema.rb` のカラム集合を Python で突合（値は一切読んでいない）。
> 「実装済み（R2）」＝対応先カラムが schema.rb に存在。「参照解決」＝FK 名寄せ（R1/R2 マスタ実装済み）。「未実装」＝Column.md 設計済みだが schema 未反映。「対応先なし」＝設計・実装とも列が無い。
> 暗号化列（`order_work_details` のアカウント8列・`orders.billing_password`）は ActiveRecord 経由で投入すること。

| # | 現行フィールド | 新スキーマ対応先 | 実装状況 | 備考 |
|---|---|---|---|---|
| 1 | 顧客番号 | `customers`.`customer_number` | 実装済み（R2） | 移行キー（顧客の起点） |
| 2 | 案件番号 | `orders`.`order_number` | 実装済み（R2） | 移行キー（案件の起点） |
| 3 | 契約者名または法人名 | `customers`.`name` | 実装済み（R2） |  |
| 4 | 契約者名または法人名カナ | `customers`.`contractor_name_kana` | 実装済み（R2） | 旧記述の`name_kana`は実装名`contractor_name_kana` |
| 5 | グループCD | 参照解決: agency_groups.group_code | 実装済み（R1/R2・FK名寄せ） | → agency_groups.id |
| 6 | グループ名 | 参照解決: agency_groups.name | 実装済み（R1/R2・FK名寄せ） | 参考（CDで解決） |
| 7 | 販売店CD | 参照解決: agencies.agency_code | 実装済み（R1/R2・FK名寄せ） | → agencies.id |
| 8 | 販売店名 | 参照解決: agencies.name | 実装済み（R1/R2・FK名寄せ） | 参考（CDで解決） |
| 9 | 営業担当者コード | 参照解決: sales_representatives.sales_rep_code | 実装済み（R1/R2・FK名寄せ） | → sales_representatives.id |
| 10 | 営業担当者名 | 参照解決: sales_representatives.name | 実装済み（R1/R2・FK名寄せ） | 参考（CDで解決） |
| 11 | アポインター担当者コード | `customers`.`appointer_code` | 実装済み（R2） |  |
| 12 | アポインター担当者名 | `customers`.`appointer_name` | 実装済み（R2） |  |
| 13 | アポインター担当者コード2 | — | 対応先なし・要確認（R7） | アポインター2人目。実装は`appointer_code/name`の1組のみ（Column.md設計も1組）。要確認（Q-移13補足） |
| 14 | アポインター担当者名2 | — | 対応先なし・要確認（R7） | 同上 |
| 15 | 請求書送付先 | `customers`.`invoice_destination` | 実装済み（R2） |  |
| 16 | 請求書送付先名 | `customers`.`invoice_name` | 実装済み（R2） |  |
| 17 | 請求書送付先名カナ | `customers`.`invoice_name_kana` | 実装済み（R2） |  |
| 18 | 請求書送付先郵便番号 | `customers`.`invoice_postal_code` | 実装済み（R2） |  |
| 19 | 請求書送付先ご住所 | `customers`.`invoice_address` | 実装済み（R2） |  |
| 20 | 日中のご連絡先電話番号 | `customers`.`invoice_phone` | 実装済み（R2） |  |
| 21 | その他の電話番号 | `customers`.`invoice_other_phone` | 実装済み（R2） |  |
| 22 | ご利用施設名称 | `stores`.`store_name` | 実装済み（R2） |  |
| 23 | ご利用施設名称（フリガナ） | `stores`.`store_name_kana` | 実装済み（R2） |  |
| 24 | 郵便番号 | `stores`.`postal_code` | 実装済み（R2） |  |
| 25 | 店舗住所 | `stores`.`prefecture`/`city`/`town`/`address_detail` | 実装済み（R2） | 住所分割（Q-移10） |
| 26 | 店舗電話番号 | `stores`.`phone_number` | 実装済み（R2） |  |
| 27 | ご連絡先FAX番号 | `stores`.`fax_number` | 実装済み（R2） |  |
| 28 | 営業時間1 | `stores`.`business_hours_1` | 実装済み（R2） |  |
| 29 | 営業時間2 | `stores`.`business_hours_2` | 実装済み（R2） |  |
| 30 | 定休日 | `stores`.`regular_holiday` | 実装済み（R2） |  |
| 31 | 会員管理ID | `orders`.`member_id` | 実装済み（R2） |  |
| 32 | 請求パスワード | `orders`.`billing_password` | 実装済み（R2） | 暗号化（encrypts） |
| 33 | 受注日（申込日） | `orders`.`ordered_at` | 実装済み（R2） | customers.applied_at にも転記 |
| 34 | 確認コール架電担当名 | `orders`.`confirm_call_staff_name` | 実装済み（R2） |  |
| 35 | 確認コール詳細 | `orders`.`confirm_call_notes` | 実装済み（R2） |  |
| 36 | 契約開始日（確認コール完了日） | `orders`.`contract_start_date` | 実装済み（R2） | customers.contracted_at にも転記 |
| 37 | 契約書送付日 | `orders`.`contract_sent_at` | 実装済み（R2） |  |
| 38 | 発注日 | `orders`.`issued_at` | 実装済み（R2） |  |
| 39 | アカウント発行日 | `orders`.`account_issued_at` | 実装済み（R2） |  |
| 40 | 作業完了日（納品完了メール送付日） | `orders`.`work_completed_at` | 実装済み（R2） | G-1 商材別分離は未対応 |
| 41 | 検収コールNG時間帯 | `orders`.`inspection_call_ng_time` | 実装済み（R2） |  |
| 42 | 検収コール履歴 | `orders`.`inspection_call_history` | 実装済み（R2） |  |
| 43 | 検収確認コール完了日 | `orders`.`inspection_call_completed_at` | 実装済み（R2） |  |
| 44 | 計上月 | `orders`.`accounting_month` | 実装済み（R2） |  |
| 45 | 決済回収日 | `orders`.`payment_collected_at` | 実装済み（R2） |  |
| 46 | 決済書類確認日 | `orders`.`payment_doc_confirmed_at` | 実装済み（R2） |  |
| 47 | 高齢者同意書 | `orders`.`elderly_consent` | 実装済み（R2） |  |
| 48 | 高齢者同意書回収日 | `orders`.`elderly_consent_collected_at` | 実装済み（R2） |  |
| 49 | 業務権限証明書 | `orders`.`business_auth_doc` | 実装済み（R2） |  |
| 50 | 業務権限証明書回収日 | `orders`.`business_auth_doc_collected_at` | 実装済み（R2） |  |
| 51 | 販管顧客コード | `customers`.`sales_mgmt_customer_code` | 実装済み（R2） |  |
| 52 | 販管売上伝票番号 | `orders`.`sales_mgmt_slip_number` | 実装済み（R2） |  |
| 53 | ファクター回収備考 | `orders`.`factor_notes` | 実装済み（R2） |  |
| 54 | おまとめ請求 | `orders`.`bundled_billing` | 実装済み（R2） |  |
| 55 | おまとめ先の案件番号 | `orders`.`bundle_target_order_number` | 実装済み（R2） |  |
| 56 | キャンセル日 | `orders`.`cancelled_at` | 実装済み（R2） |  |
| 57 | 解約日 | `orders`.`terminated_at` | 実装済み（R2） |  |
| 58 | 解約理由 | `orders`.`termination_reason` | 実装済み（R2） |  |
| 59 | 顧客ステータス | `orders`.`status` | 実装済み（R2） | 旧→新コード変換（C-6）。customers.status にも反映 |
| 60 | プラン名 | 参照解決: plans.id | 実装済み（R1/R2・FK名寄せ） | orders.plan_id（プラン名で名寄せ） |
| 61 | 月額料金 | `plans`.`monthly_fee` | 実装済み（R2） | 参照導出。スナップショット要否 Q-移15 |
| 62 | 初期費用 | 参照解決: product_initial_fees.id | 実装済み（R1/R2・FK名寄せ） | orders.product_initial_fee_id |
| 63 | システムアカウントID | `order_work_details`.`system_account_id` | 実装済み（R2） | 暗号化。Q-移16 |
| 64 | システムアカウントPASS | `order_work_details`.`system_account_pass` | 実装済み（R2） | 暗号化 |
| 65 | Instagramアカウント | `order_work_details`.`instagram_account` | 実装済み（R2） |  |
| 66 | Instagram ID | `order_work_details`.`instagram_id` | 実装済み（R2） | 暗号化 |
| 67 | Instagram PASS | `order_work_details`.`instagram_pass` | 実装済み（R2） | 暗号化 |
| 68 | GBP権限 | `order_work_details`.`gbp_permission` | 実装済み（R2） |  |
| 69 | 履歴記載枠（運用） | `order_work_details`.`operation_history` | 実装済み（R2） |  |
| 70 | 作業進行備考 | `order_work_details`.`work_progress_notes` | 実装済み（R2） |  |
| 71 | 業種 | `customers`.`industry` | 実装済み（R2） |  |
| 72 | 業種（小区分） | `customers`.`industry_sub` | 実装済み（R2） |  |
| 73 | Bridge移行 | `orders`.`bridge_migration` | 実装済み（R2） |  |
| 74 | Bridge移行案件番号 | `orders`.`bridge_migration_order_number` | 実装済み（R2） |  |
| 75 | Bridge計上月 | `orders`.`bridge_accounting_month` | 実装済み（R2） |  |
| 76 | Bridge販売店名 | `orders`.`bridge_agency_name` | 実装済み（R2） |  |
| 77 | Bridge営業担当者名 | `orders`.`bridge_sales_rep_name` | 実装済み（R2） |  |
| 78 | 管理者メールアドレス | `customers`.`email` | 実装済み（R2） | 149と重複。email はUNIQUE制約あり（複数値・重複時の扱い要確認） |
| 79 | 店舗メールアドレス | — | 対応先なし・要確認（R7） | 店舗メール。stores にメール列なし（Column.md設計にも無し）。要確認 |
| 80 | 契約者区分 | `customers`.`applicant_type` | 実装済み（R2） |  |
| 81 | 確認コール連絡希望日 | `orders`.`confirm_call_preferred_date` | 実装済み（R2） |  |
| 82 | 確認コール架電時間 | `orders`.`confirm_call_time` | 実装済み（R2） |  |
| 83 | 連絡先固定電話番号 | `customers`.`phone` | 実装済み（R2） | Column.md `phone_number` は実装 `phone` に読み替え |
| 84 | 携帯電話番号 | `customers`.`mobile_phone` | 実装済み（R2） |  |
| 85 | 契約者名 | `customers`.`contact_name` | 実装済み（R2） | 「契約者名」＝担当者名と推定。要確認 |
| 86 | 担当者役職　※個人事業主の場合、必ず代表 | `customers`.`contact_title` | 実装済み（R2） |  |
| 87 | 確認コール担当者名 | `orders`.`confirm_call_contact_name` | 実装済み（R2） |  |
| 88 | お支払方法 | `orders`.`payment_method` | 実装済み（R2） |  |
| 89 | 用紙の送付先住所記載 | `orders`.`paper_address_note` | 実装済み（R2） |  |
| 90 | 確認コール備考 | `orders`.`confirm_call_remarks` | 実装済み（R2） |  |
| 91 | 個人事業主の場合事業証明 | `orders`.`business_proof` | 実装済み（R2） |  |
| 92 | 同意状況 | `orders`.`consent_status` | 実装済み（R2） |  |
| 93 | 同意時 代表者年齢 | `orders`.`consent_rep_age` | 実装済み（R2） |  |
| 94 | 同意時 担当者年齢 | `orders`.`consent_contact_age` | 実装済み（R2） |  |
| 95 | MEO施策管理番号 | `orders`.`meo_mgmt_number` | 実装済み（R2） |  |
| 96 | トスアップCD | `orders`.`toss_up_code` | 実装済み（R2） |  |
| 97 | 契約者郵便番号 | `customers`.`postal_code` | 実装済み（R2） |  |
| 98 | 契約者住所 | `customers`.`prefecture`/`city`/`town`/`address_detail` | 実装済み（R2） | 住所パース（Q-移17） |
| 99 | シリアルID | `orders`.`serial_id` | 実装済み（R2） |  |
| 100 | プラン | 参照解決: plans.id | 実装済み（R1/R2・FK名寄せ） | 60と同じ（重複列） |
| 101 | 契約会社名 | `customers`.`name` | 実装済み（R2） | 3と重複（電子契約作業項目側） |
| 102 | ご代表者様のお名前 | `customers`.`representative_name` | 実装済み（R2） |  |
| 103 | ご代表者様のお名前(フリガナ) | `customers`.`representative_name_kana` | 実装済み（R2） |  |
| 104 | 郵便番号 | `stores`.`postal_code` | 実装済み（R2） | 24と重複 |
| 105 | 住所 | `stores`.`prefecture`/`city`/`town`/`address_detail` | 実装済み（R2） | 25と重複 |
| 106 | 店舗電話番号 | `stores`.`phone_number` | 実装済み（R2） | 26と重複 |
| 107 | FAX番号 | `stores`.`fax_number` | 実装済み（R2） | 27と重複 |
| 108 | ビジネスプロフィールのサイトURL | `order_work_details`.`gbp_site_url` | 実装済み（R2） |  |
| 109 | 営業時間 | `stores`.`business_hours_1` | 実装済み（R2） | 28と重複 |
| 110 | 定休日 | `stores`.`regular_holiday` | 実装済み（R2） | 30と重複 |
| 111 | 最寄駅 | `order_work_details`.`nearest_station` | 実装済み（R2） |  |
| 112 | 道順 | `order_work_details`.`directions` | 実装済み（R2） |  |
| 113 | 駐車場 | `order_work_details`.`parking` | 実装済み（R2） |  |
| 114 | 駐車可能な台数 | `order_work_details`.`parking_capacity` | 実装済み（R2） |  |
| 115 | 利用できるクレジットカードの種類 | `order_work_details`.`accepted_cards` | 実装済み（R2） |  |
| 116 | 開業日 | `order_work_details`.`opening_date` | 実装済み（R2） |  |
| 117 | 従業員数 | `order_work_details`.`num_employees` | 実装済み（R2） |  |
| 118 | 資本金　※法人の場合必須 | `order_work_details`.`capital` | 実装済み（R2） |  |
| 119 | 担当者名 | `customers`.`contact_name` | 実装済み（R2） | 85と重複 |
| 120 | 担当者の生年月日 | — | 対応先なし・要確認（R7） | 担当者の生年月日。対応列なし（Column.md設計にも無し）。要確認 |
| 121 | 担当者の電話番号 | `customers`.`contact_dept_phone` | 実装済み（R2） | 担当者電話。`contact_dept_phone`（部署電話）へ充当するか要確認 |
| 122 | キーワード（地域＋業種） | `order_work_details`.`keyword_region_industry` | 実装済み（R2） |  |
| 123 | Google ビジネスプロフィール URL | `order_work_details`.`gbp_url` | 実装済み（R2） |  |
| 124 | Instagram ID | `order_work_details`.`instagram_id` | 実装済み（R2） | 66と重複 |
| 125 | Instagram PASS | `order_work_details`.`instagram_pass` | 実装済み（R2） | 67と重複 |
| 126 | FacebookID | `order_work_details`.`facebook_id` | 実装済み（R2） | 暗号化 |
| 127 | FacebookPASS | `order_work_details`.`facebook_pass` | 実装済み（R2） | 暗号化 |
| 128 | バリアフリーの有無 | `order_work_details`.`barrier_free` | 実装済み（R2） |  |
| 129 | 設備：Wi-Fiの有無（なし or 無料Wi-Fi or 有料Wi-Fi） | `order_work_details`.`wifi_available` | 実装済み（R2） |  |
| 130 | ロゴ・写真データなど | `order_work_details`.`logo_photo` | 実装済み（R2） |  |
| 131 | ヒアリングシステム | `order_work_details`.`hearing_system` | 実装済み（R2） |  |
| 132 | 営業担当 | — | 対応先なし・要確認（R7） | ヒアリングシステム関連の担当。用途不明。要確認 |
| 133 | 販売店 | — | 対応先なし・要確認（R7） | 同上 |
| 134 | 担当 | — | 対応先なし・要確認（R7） | 同上 |
| 135 | 契約会社名フリガナ | `customers`.`contractor_name_kana` | 実装済み（R2） | 4と重複 |
| 136 | 店舗名 | `stores`.`store_name` | 実装済み（R2） | 22と重複 |
| 137 | 店舗名フリガナ | `stores`.`store_name_kana` | 実装済み（R2） | 23と重複 |
| 138 | ご利用の店舗数 | `order_work_details`.`num_stores` | 実装済み（R2） |  |
| 139 | ビジネスアカウント名 | `order_work_details`.`business_account_name` | 実装済み（R2） |  |
| 140 | キーワード(ビジネスカテゴリー) | `order_work_details`.`business_category_keyword` | 実装済み（R2） |  |
| 141 | 業種キーワード | `order_work_details`.`industry_keyword` | 実装済み（R2） |  |
| 142 | お客様情報参考サイトURL | `order_work_details`.`reference_url` | 実装済み（R2） |  |
| 143 | Facebookアカウントの所持 | `order_work_details`.`has_facebook` | 実装済み（R2） |  |
| 144 | Instagramアカウントの所持 | `order_work_details`.`has_instagram` | 実装済み（R2） |  |
| 145 | Googleビジネスアカウントの所持 | `order_work_details`.`has_google_business` | 実装済み（R2） |  |
| 146 | オーナー権限 | `order_work_details`.`gbp_owner_permission` | 実装済み（R2） |  |
| 147 | オーナー権限所有者名・担当者名 | `order_work_details`.`gbp_owner_name` | 実装済み（R2） |  |
| 148 | オーナー権限所有者・担当者連絡先 | `order_work_details`.`gbp_owner_contact` | 実装済み（R2） |  |
| 149 | メールアドレス | `customers`.`email` | 実装済み（R2） | 78と重複 |
| 150 | 業態 | `order_work_details`.`business_type` | 実装済み（R2） |  |
| 151 | 属性1 | `order_work_details`.`attribute_1` | 実装済み（R2） |  |
| 152 | 属性2 | `order_work_details`.`attribute_2` | 実装済み（R2） |  |
| 153 | 属性3 | `order_work_details`.`attribute_3` | 実装済み（R2） |  |
| 154 | 属性4 | `order_work_details`.`attribute_4` | 実装済み（R2） |  |
| 155 | 属性5 | `order_work_details`.`attribute_5` | 実装済み（R2） |  |
| 156 | 属性6 | `order_work_details`.`attribute_6` | 実装済み（R2） |  |
| 157 | 属性7 | `order_work_details`.`attribute_7` | 実装済み（R2） |  |
| 158 | 属性8 | `order_work_details`.`attribute_8` | 実装済み（R2） |  |
| 159 | 属性9 | `order_work_details`.`attribute_9` | 実装済み（R2） |  |
| 160 | 属性10 | `order_work_details`.`attribute_10` | 実装済み（R2） |  |
| 161 | 属性11 | `order_work_details`.`attribute_11` | 実装済み（R2） |  |
| 162 | ランチ | `order_work_details`.`lunch_hours` | 実装済み（R2） |  |
| 163 | ディナー | `order_work_details`.`dinner_hours` | 実装済み（R2） |  |
| 164 | 入店可能時間 | `order_work_details`.`available_from` | 実装済み（R2） |  |
| 165 | 注文可能時間 | `order_work_details`.`order_time` | 実装済み（R2） |  |
| 166 | システムアカウントPASS | `order_work_details`.`system_account_pass` | 実装済み（R2） | 64と重複 |
| 167 | 契約開始日 | `orders`.`contract_start_date` | 実装済み（R2） | 36と重複 |
| 168 | 契約単位 | `plans`.`contract_unit` | 未実装（Column.md設計済み・schema未反映。R7着手前に要否判断） | Column.md §4 plans に設計済みだが schema.rb 未反映（Q-移18） |
| 169 | 初期構築 | `plans`.`initial_construction` | 未実装（Column.md設計済み・schema未反映。R7着手前に要否判断） | 同上（Q-移18） |
| 170 | Plus | `orders`.`plus_applied` | 実装済み（R2） |  |
| 171 | Plus申込有無 | `orders`.`plus_applied` | 実装済み（R2） | 170と重複 |
| 172 | 契約ステータス | `orders`.`contract_status` | 実装済み（R2） |  |
| 173 | 代表者名_姓 | `customers`.`representative_name` | 実装済み（R2） | 姓＋名を結合（102と重複） |
| 174 | 代表者名_名 | `customers`.`representative_name` | 実装済み（R2） | 同上 |
| 175 | 代表者名_姓_カナ | `customers`.`representative_name_kana` | 実装済み（R2） | 結合 |
| 176 | 代表者名_名_カナ | `customers`.`representative_name_kana` | 実装済み（R2） | 結合 |
| 177 | 電話番号_市外局番 | `customers`.`phone` | 実装済み（R2） | 市外＋市内＋番号を結合（83と重複） |
| 178 | 電話番号_市内局番 | `customers`.`phone` | 実装済み（R2） | 同上 |
| 179 | 電話番号_番号 | `customers`.`phone` | 実装済み（R2） | 同上 |
| 180 | 住所_都道府県 | `customers`.`prefecture` | 実装済み（R2） |  |
| 181 | 住所_市区町村 | `customers`.`city` | 実装済み（R2） |  |
| 182 | 住所_町名 | `customers`.`town` | 実装済み（R2） |  |
| 183 | 住所_丁目番地 | `customers`.`address_detail` | 実装済み（R2） |  |
| 184 | 住所_建物名 | `customers`.`address_detail` | 実装済み（R2） | 建物名は address_detail へ結合（専用列なし） |
| 185 | サイテーション申し込み | `orders`.`citation_applied` | 実装済み（R2） |  |
| 186 | Sプラン CMS | `orders`.`s_plan_cms` | 実装済み（R2） |  |
| 187 | Owlet CMS | `orders`.`owlet_cms` | 実装済み（R2） |  |
| 188 | Onerank CMS | `orders`.`onerank_cms` | 実装済み（R2） |  |
| 189 | サイテーション申し込み数 | `orders`.`citation_count` | 実装済み（R2） |  |
| 190 | 備考 | `orders`.`remarks` | 実装済み（R2） | order_work_details 側と重複注意 |
| 191 | Instagramアカウントのログイン確認 | `order_work_details`.`instagram_login_confirmed` | 実装済み（R2） |  |
| 192 | オーナー権限付与 | `order_work_details`.`gbp_owner_permission_granted` | 実装済み（R2） |  |
| 193 | 連絡が取りやすい時間帯 | `order_work_details`.`contact_easy_time` | 実装済み（R2） |  |
| 194 | 連絡が取りやすい時間帯【その他】 | `order_work_details`.`contact_easy_time_note` | 実装済み（R2） |  |
| 195 | 連絡が取りやすい曜日 | `order_work_details`.`contact_easy_day` | 実装済み（R2） |  |
| 196 | 連絡が取りやすい曜日【その他】 | `order_work_details`.`contact_easy_day_note` | 実装済み（R2） |  |
| 197 | 外部リンク申し込み | `orders`.`external_link_applied` | 実装済み（R2） |  |
| 198 | 外部リンク申し込み数 | `orders`.`external_link_count` | 実装済み（R2） |  |
| 199 | 外部リンクの型 | `orders`.`external_link_type` | 実装済み（R2） |  |
| 200 | サイテーション既存シリアル | `orders`.`citation_existing_serial` | 実装済み（R2） |  |
| 201 | GBPインバウンド多言語対策 | `orders`.`gbp_multilingual` | 実装済み（R2） |  |
| 202 | 言語選択 | `orders`.`language_selection` | 実装済み（R2） |  |
| 203 | MEO既存シリアル | `orders`.`meo_existing_serial` | 実装済み（R2） |  |
| 204 | info Biz申し込み | `orders`.`infobiz_applied` | 実装済み（R2） |  |
| 205 | 国内サイテーションプラン | `orders`.`domestic_citation_plan` | 実装済み（R2） |  |
| 206 | キーワード_都道府県 | `order_work_details`.`keyword_prefecture` | 実装済み（R2） |  |
| 207 | キーワード_市町村 | `order_work_details`.`keyword_city` | 実装済み（R2） |  |
| 208 | キーワード_通称エリア名1 | `order_work_details`.`keyword_area_1` | 実装済み（R2） |  |
| 209 | キーワード_通称エリア名2 | `order_work_details`.`keyword_area_2` | 実装済み（R2） |  |
| 210 | キーワード_通称エリア名3 | `order_work_details`.`keyword_area_3` | 実装済み（R2） |  |
| 211 | 業種やサービス_メイン | `order_work_details`.`keyword_industry_main` | 実装済み（R2） |  |
| 212 | 業種やサービス_サブ1 | `order_work_details`.`keyword_industry_sub1` | 実装済み（R2） |  |
| 213 | 業種やサービス_サブ2 | `order_work_details`.`keyword_industry_sub2` | 実装済み（R2） |  |
| 214 | 業種やサービス_サブ3 | `order_work_details`.`keyword_industry_sub3` | 実装済み（R2） |  |
| 215 | 業種やサービス_サブ4 | `order_work_details`.`keyword_industry_sub4` | 実装済み（R2） |  |
| 216 | キーワード備考　※通称エリア設定理由など | `order_work_details`.`keyword_remarks` | 実装済み（R2） |  |
| 217 | サイテーションプラン | `orders`.`citation_plan` | 実装済み（R2） |  |
| 218 | 信販区分 | `orders`.`finance_division` | 実装済み（R2） |  |
| 219 | 設置先（アシスト信販） | `orders`.`finance_installer` | 実装済み（R2） |  |
| 220 | 設置先郵便番号 | `orders`.`finance_postal_code` | 実装済み（R2） |  |
| 221 | 設置先_都道府県 | `orders`.`finance_prefecture` | 実装済み（R2） |  |
| 222 | 設置先_市区町村 | `orders`.`finance_city` | 実装済み（R2） |  |
| 223 | 設置先_町名 | `orders`.`finance_town` | 実装済み（R2） |  |
| 224 | 設置先_番地 | `orders`.`finance_address_detail` | 実装済み（R2） |  |
| 225 | 設置先_ビル名 | `orders`.`finance_building` | 実装済み（R2） |  |
| 226 | 設置先電話番号 | `orders`.`finance_phone` | 実装済み（R2） |  |
| 227 | 共有事項 | `orders`.`shared_notes` | 実装済み（R2） |  |
| 228 | MEOプレミアム強化プランの申し込み | `orders`.`meo_premium_applied` | 実装済み（R2） |  |
| 229 | Google広告申し込み | `orders`.`google_ads_applied` | 実装済み（R2） |  |
| 230 | Google広告申し込み数 | `orders`.`google_ads_count` | 実装済み（R2） |  |
| 231 | Google口コミ表示 | `orders`.`google_review_display` | 実装済み（R2） |  |
| 232 | 口コミ表示の見出し名 | `orders`.`review_heading` | 実装済み（R2） |  |
| 233 | ID | — | 対応先なし・要確認（R7） | 「ID」用途不明。要確認 |
| 234 | 予約システム | `orders`.`reservation_system` | 実装済み（R2） |  |
| 235 | ポータルサイト掲載の申し込み | `orders`.`portal_site_applied` | 実装済み（R2） |  |
| 236 | GoogleアカウントID | `order_work_details`.`google_account_id` | 実装済み（R2） | 暗号化 |
| 237 | GoogleアカウントPASS | `order_work_details`.`google_account_pass` | 実装済み（R2） | 暗号化 |
| 238 | 既存GBP削除し、新規作成希望 | `order_work_details`.`gbp_delete_new` | 実装済み（R2） |  |
