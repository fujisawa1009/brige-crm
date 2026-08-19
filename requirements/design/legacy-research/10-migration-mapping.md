# データ移行 新旧カラムマッピング（DM-2）

> 作成日: 2026-07-24
> 出典: 現行DB退避CSV（実カラム）× 新スキーマ（マイグレーション実カラム）
> 位置づけ: `09-data-cleansing.md` の整形ルールを**カラム単位の対応表**に落とす。`release-readiness.md` B-3 の本体。
> ⚠️ 実データ（PII）を含む。値は転記せず、構造・対応のみ記載。
>
> **Rails版改訂: 2026-08-19。** 旧Laravelプロジェクト（`boilerplate-vue-env/laravel/requirements/design/legacy-research/10-migration-mapping.md`）を
> brige-crm（Rails 8.1）の現行実装（`db/schema.rb`）・03/04 の決定に合わせて見直し。**フェーズ対応: R7（データ移行。旧 P5-5 相当）／マッピング先は R1/R2/R4 実装済みスキーマ。**
> - 調査事実（現行CSVの列構造・件数・破損・ヘッダ有無）は改変していない。改訂したのは「新カラム」列の表記と実装状況の付記のみ。
> - 読み替え: `organizations.id` → `agency_groups.id` / `agencies.id`（Rails版に organizations テーブルは無い）、`jasmin_stores` → `stores`、`jasmin_customer_id` → `customer_id`、`jasmin_orders` → `orders`、`updateOrCreate` → ActiveRecord の `find_or_initialize_by` / `upsert_all`。
> - 掲示板（§6）の移行先は「Q-C 確定後に定義」から **R4 実装済みの `inquiries` / `inquiry_messages`（掲示板4種→問い合わせ統合。決定D-11）** に更新。
> - 各表に **「実装状況」列を追加**（2026-08-19 時点の `db/schema.rb` と突合）。

---

## 0. このノートの使い方

`09` が「どう整形するか（ルール）」、本書が「どの列をどの列へ（対応）」。
ETL 実装（`09` §6）は本書の対応表を参照して変換ロジックを書く。

**表記**：`結合`＝複数列を1列へ / `変換`＝コード→値 / `名寄せ`＝文字列→ID / `新規`＝新カラム無し（要追加判断）。

---

## 1. ⚠️ 追加で判明した整形課題：ヘッダ無しCSV

`09` §1 の破損（営業担当ヘッダ13/16列・店舗Plus 1行47列）に加え、精査で**新たな課題**を検出。

| CSV | ヘッダ | 対応 |
|---|---|---|
| グループ一覧_bridge | **無し**（データ行から開始） | カラム定義を人手で確定（§2） |
| 代理店一覧_bridge | **無し**（データ行から開始） | 同上（§3） |
| 営業担当者一覧_bridge | 有り（**破損13/16列**） | データ16列を正として復元（§4） |
| 施工担当者一覧_bridge | 有り（sekou_id/cd/name） | そのまま |
| 店舗一覧_bridge(_plus) | 有り（24列） | §5。Plusの47列行は隔離 |
| 掲示板_bridge(_plus) | 有り（34列） | §6 |

> **教訓**：CSVごとにヘッダ有無・破損状況が異なる。**CSVヘッダを一切信用せず、
> 全CSVで列定義マスタを人手で確定してから**パースする（`09` C-1 の徹底）。

---

## 2. グループ一覧_bridge → agency_groups

**現行6列（ヘッダ無し・値位置から推定）**

| 位置 | 推定内容 | 新カラム | 整形 | 実装状況（2026-08-19） |
|---|---|---|---|---|
| 1 | group_id（例 9） | `agency_groups.id`（新規UUID採番） | 旧IDは移行ログに保持 | 実装済み（R1。UUID主キー） |
| 2 | group_cd（例 970393） | `agency_groups.group_code` | そのまま（業務CD） | 実装済み（R1。UNIQUE） |
| 3 | group_name（例 NEXTﾊﾟｰﾄﾅｰ（ショット）） | `agency_groups.name` | **半角カナ正規化** | 実装済み（R1） |
| 4 | （空・用途不明） | — | 要確認 | — |
| 5 | 区分（例 B） | — | Bridge/BridgePlus 判別に使える可能性。要確認 | **Rails版で `agency_groups.service_type`（NOT NULL）が追加実装済み**（R1）。位置5の区分がこれに対応する可能性が高い（要確認 Q-移11。対応しない場合は移行時に既定値が必要） |
| 6 | （空） | — | — | — |

**未対応の新カラム**：`contact_email` / `bridge_plan_display_type` / `csv_download_visible`（いずれも R1 実装済み・NULL 許容）
→ 現行CSVに該当列が見当たらない。**別ソース（案件CSV/仕様書）から補完 or NULL**。要確認（Q-移6）。

---

## 3. 代理店一覧_bridge → agencies

**現行19列（ヘッダ無し・値位置から推定）**

| 位置 | 推定内容 | 新カラム | 整形 | 実装状況（2026-08-19） |
|---|---|---|---|---|
| 1 | agency_id（例 76） | `agencies.id`（新規UUID） | 旧ID保持 | 実装済み（R1） |
| 2 | agency_cd（例 970393） | `agencies.agency_code` | そのまま。※グループCDと同値のケース＝グループ兼代理店（Q-9） | 実装済み（R1。UNIQUE） |
| 3 | agency_name | `agencies.name` | 半角カナ正規化 | 実装済み（R1） |
| 4 | group_id（例 9） | `agencies.agency_group_id` | **旧group_id→新 `agency_groups.id` へ名寄せ** | 実装済み（R1。NOT NULL・FK restrict） |
| 5 | （例 36） | — | 用途不明（施工担当/エリア?）要確認 | — |
| 6-7 | 空（郵便番号想定） | `agencies` に郵便カラム無し | **新規**（要追加判断） | 未実装（Q-移7 残存） |
| 6 | prefecture_id（例 12=千葉） | — | 変換（コード→都道府県名） | 未実装（同上） |
| 7 | city（柏市中央） | — | agencies に住所カラム無し → **新規判断** | 未実装（同上） |
| 8-9 | address / building | — | 同上 | 未実装（同上） |
| 10-15 | 空（tel/fax） | — | agencies に電話カラム無し → **新規判断** | 未実装（同上） |
| 16 | email | `agencies.email_1` | email_1〜5 のうち 1 へ | 実装済み（R1） |

**未対応の新カラム**：`contact_person` / `email_2〜5` / `electronic_contract_enabled` / `csv_download_visible`（いずれも R1 実装済み・NULL 許容）
→ 現行に列が無い。BridgePlus側は仕様書・案件CSVから補完。**Bridge側はNULL**（設計どおり）。

> ⚠️ **agencies には住所・電話カラムが無い**（設計上、住所は組織固有情報として持たない方針。**Rails版 `db/schema.rb` でも同じ＝Q-移7 は残存**）。
> 現行の代理店住所・電話を移行するなら**カラム追加が必要**。要否を確認（Q-移7。R7 着手前に判断）。
> ※ ただし PDF出力用住所は `sales_representatives.pdf_*` にある（営業担当者単位。R1 実装済み）。

---

## 4. 営業担当者一覧_bridge → sales_representatives

**現行16列（ヘッダ破損・データ16列を正とする）**

| 位置 | 推定内容 | 新カラム | 整形 | 実装状況（2026-08-19） |
|---|---|---|---|---|
| 1 | resp_id | `sales_representatives.id`（新規UUID） | 旧ID保持 | 実装済み（R1） |
| 2 | resp_cd | `sales_rep_code` | **グローバルユニーク化**（T-2。現行は複合ユニーク） | 実装済み（R1。UNIQUE index。**旧データに重複CDがあれば移行前に解消が必要**） |
| 3 | resp_name | `name` | — | 実装済み（R1） |
| 4 | resp_shop_name | `pdf_store_name` | PDF出力用店所名 | 実装済み（R1） |
| 5-6 | resp_shop_post_1/2 | `pdf_postal_code` | **結合**（3桁-4桁） | 実装済み（R1） |
| 7 | resp_shop_prefecture_id | `pdf_prefecture` | **変換**（コード→名称） | 実装済み（R1） |
| 8-10 | resp_shop_address_1/2/3 | `pdf_city` / `pdf_town` / `pdf_address_detail` | **分割対応**（市区/町名/番地へ振り分け） | 実装済み（R1） |
| 11-13 | resp_shop_tel_1/2/3 | `pdf_phone_number` | **結合**（ハイフン） | 実装済み（R1） |
| 14-16 | resp_shop_fax_1/2/3 | `pdf_fax_number` | **結合** | 実装済み（R1） |

**未対応の新カラム**：`agency_id`（所属代理店。**NOT NULL・FK**）→ 現行の営業担当CSVに代理店IDが**無い**。
BridgePlus側の `BP_all_resp`（310件）や案件データから**代理店との紐づけを別途復元**（Q-移8）。**復元できない担当者は投入不可**（NOT NULL）のため、未解決分の受け皿（移行用ダミー代理店 or 除外）を R7 で決める。
`email` / `is_active` も現行CSVに無い → 補完 or 既定値（`is_active` は既定 true）。**Rails版注記**: `email` は受注入力ログインのメールOTP送信先（R3。`Form::OtpsController`）で、未設定の担当者は受注入力にログインできない。移行時に別ソースから補完するか、初回ログイン前に管理画面で登録する運用にするかを決める（要確認）。

> ⚠️ address_1/2/3 → city/town/address_detail の**振り分けルールが自明でない**
> （現行は3分割、新は市区/町名/番地の3分割だが対応が1:1とは限らない）。サンプルで要検証。

---

## 5. 店舗一覧_bridge(_plus) → stores

**現行24列（ヘッダ有り）**

| 現行列 | 新カラム（`stores`） | 整形 | 実装状況（2026-08-19） |
|---|---|---|---|
| l_store_place_cd | `store_code` | そのまま | 実装済み（R2。非UNIQUE index） |
| facility_name | `store_name` | — | 実装済み（R2。NOT NULL） |
| facility_name_kana | `store_name_kana` | 半角カナ正規化 | 実装済み（R2） |
| post_1 + post_2 | `postal_code` | **結合**（3桁-4桁） | 実装済み（R2。string(8)） |
| prefecture_id | `prefecture` | **変換**（コード→名称） | 実装済み（R2） |
| address_1 / 2 / 3 | `city` / `town` / `address_detail` | **分割対応**（§4 と同じ課題） | 実装済み（R2） |
| tel_1/2/3 | `phone_number` | **結合** | 実装済み（R2。string(20)） |
| fax_1/2/3 | `fax_number` | **結合** | 実装済み（R2） |
| space_open_time(_min) + space_close_time(_min) | `business_hours_1` | **結合**（`HH:MM〜HH:MM`） | 実装済み（R2。string(50)） |
| space_open_time2(_min) + space_close_time2(_min) | `business_hours_2` | 同上（2枠目） | 実装済み（R2） |
| space_regular_holiday | `regular_holiday` | — | 実装済み（R2。string(100)） |

**未対応の新カラム**：`customer_id`（顧客紐づけ。**NOT NULL・FK**）→ 現行店舗CSVに顧客IDが**無い**。
案件CSV（all_bridge/plus）経由で顧客と店舗を紐づける必要がある（Q-移9）。**紐づかない店舗は投入不可**（NOT NULL）のため、投入順序は「顧客→（案件CSVで紐づけ解決）→店舗」。
`is_active` は既定 true。**Rails版注記**: `stores` にメールアドレス列は無い（旧「店舗メールアドレス」（案件238の79）は対応先なし。`11` §5）。

> **Plusの47列破損行（1件）は隔離**（`09` C-1b）。24列に収まらない行はパースせず要目視。

---

## 6. 掲示板_bridge(_plus) → 問い合わせ（`inquiries` / `inquiry_messages`。R4 実装済み・掲示板統合）

**現行34列（横持ち）→ 縦持ちへ正規化**（`09` C-3）。初版では「新テーブルは Q-C 確定後に定義」としていたが、
**Rails版では決定D-11（`board-implementation-options.md` 推奨案①）により掲示板4種は `Inquiry` に統合され R4 で実装済み**。
移行先は下表の通り（`db/schema.rb` 2026-08-19）。掲示板42万件は参照アーカイブ（Q-C 決定済み・04 R7）。

| 現行列 | 移行後の扱い | 移行先（Rails版） | 実装状況 |
|---|---|---|---|
| bbs_id | 旧ID保持（`find_or_initialize_by` / `upsert_all` の冪等キー） | **`inquiries` / `inquiry_messages` に旧ID列は無い** → 移行ログテーブル（`09` §6-2 `legacy_migration_logs` 相当）で旧ID↔新UUID を保持 | 未実装（R7。旧ID保持列 or 移行ログテーブルの追加が必要） |
| commodity_type | **変換**（Bridge/BridgePlus 判別） | 案件（`orders`）経由で商材が決まるため直接の列は不要。判定にのみ使う | — |
| target_id | 案件（orders）へ**名寄せ**（旧案件ID→新UUID） | `inquiries.order_id`（**NOT NULL・FK restrict**）。案件に紐づかない投稿は投入不可 → 受け皿（移行用ダミー案件 or 除外）を R7 で決める | 実装済み（R4） |
| parent_bbs_id | スレッド親（返信構造の復元） | 親＝`inquiries`（スレッド）、子＝`inquiry_messages`（`inquiry_id`・`created_at` 順） | 実装済み（R4） |
| latest_flg / after_flg | 最新版/アフター判定 | `latest_flg` はスレッド化で不要。`after_flg` → `inquiries.category = "アフター問合せ"` | 実装済み（R4） |
| bbs_status / bbs_after_status / bbs_ac_call_status / bbs_creation_status | **どれに値が入るかで掲示板種別（後確/アフター/検収コール/制作）を判定** → 種別列＋ステータス列へ縦展開 | `inquiries.category`（`後確` / `制作対応` / `検収コール` / `アフター問合せ` の4値。`Inquiry::CATEGORIES`）＋ `inquiries.status`（`inquiry_statuses` マスタ。category 単位のコード集合） | 実装済み（R4）。旧ステータス値→`inquiry_statuses.code` の変換表は R7 |
| bbs_category_1/2/3 / bbs_category_sw / receiving_desc | アフター掲示板のカテゴリ・受電窓口 | `inquiries.after_urgency` / `after_type` / `after_area` / `reception_channel`（string・任意） | 実装済み（列のみ R4。入力UI・選択肢マスタは未実装＝`board-implementation-options.md`） |
| manager / contributor / n_manager / n_contributor / f_manager / f_contributor | 対応者・投稿者 → **名寄せ**（手入力文字列→ユーザID。未一致は不明ユーザ） | 投稿者＝`inquiry_messages.created_by_id`（`users` FK・NULL可）。初回/次回対応者＝`inquiries.first_responder_name` / `next_responder_name`（**自由文字列**） | 実装済み（R4）。**名寄せ手順は `../name-matching-process.md`（R7 未実装）**。`created_by_id` は `users` 限定のため営業担当者/顧客の投稿は原文名の保持で受ける（`legacy_poster_name` 列は未実装・R7 要求事項） |
| title / body | タイトル・本文（2000字分割投稿の再構成方針・改行クレンジング） | `inquiries.title` ＋ `inquiry_messages.body`（text・NOT NULL） | 実装済み（R4） |
| make_type / admin_id | 作成種別・管理者 | `admin_id` → `inquiry_messages.created_by_id`（社内ユーザに解決できる場合）。`make_type` は保持先なし | 一部（要確認） |
| first_insert_* | 初回投入時の値（監査・履歴として保持するか判断） | 保持先なし（`audit_logs` は移行投入の変更履歴を自動記録するが旧値の器ではない） | 要確認（R7） |

> **42万件（Bridge 77,981 + Plus 342,594）**。移行範囲（全件/直近/アーカイブ）は Q-C と一体で決定 → 04 R7「掲示板42万件は参照アーカイブ（Q-C 決定済み）」。
> **Rails版注記**: `inquiries.inquiry_number`（`INQ-xxxxxx`・`SequenceCounter` 採番・UNIQUE）は移行分にも必要。42万件を本番 `inquiries` に投入するか別アーカイブテーブルにするかは、参照アーカイブの実装方式（R7）で決める。

---

## 7. 案件（all_bridge / all_bridge_plus）→ orders

受注238カラム相当。本体は **`11-order-field-mapping.md`**（全238フィールドの対応と `db/schema.rb` 突合結果＝付録A）。
案件CSVは店舗・顧客・営業担当・代理店の**紐づけの起点**（§5 の `stores.customer_id`、§4 の `sales_representatives.agency_id` を復元する鍵）。

---

## 8. マッピングから生じた確認事項

| # | 論点 |
|---|---|
| Q-移6 | グループの `contact_email` / `bridge_plan_display_type` / `csv_download_visible` の補完元（残存・R7） |
| Q-移7 | agencies に住所・電話カラムを追加するか（現行代理店の住所・電話を移行するか）（**残存**。Rails版 schema にも無し・04 R7 既知事項） |
| Q-移8 | 営業担当者→代理店の紐づけ（`agency_id`。Rails版は NOT NULL）の復元元（案件CSV / BP_all_resp）（残存・R7） |
| Q-移9 | 店舗→顧客の紐づけ（`stores.customer_id`。Rails版は NOT NULL）の復元元（案件CSV）（残存・R7） |
| Q-移10 | address_1/2/3 → city/town/address_detail の分割対応ルール（サンプル検証が必要）（残存・R7） |
| Q-移11 | グループ・代理店CSVのヘッダ無し列（位置4・5等）の意味確定（残存。位置5は `agency_groups.service_type` 対応の可能性） |
| Q-移19（Rails版追加） | 営業担当者 `email`（受注入力OTP送信先）の補完元と、未設定担当者の初回ログイン運用 |
| Q-移20（Rails版追加） | 案件投入に必須の `orders.contract_condition_id`（NOT NULL）の扱い（移行用既定契約条件を代理店ごとに生成するか） |

---

## 8-2. サンプル検証（マッピングの裏付け）

実データのサンプルでマッピング仮説を検証した（値は非表示・分布のみ）。

| 検証 | 結果 |
|---|---|
| **掲示板の種別判定**（bbs_status系4列） | ✅ 掲示板5,000行で**4列は排他的に1つだけ埋まる**（複数同時に埋まる行なし）。§6 の「どの列に値が入るかで掲示板種別を判定」が**構造的に機能**する。内訳：bbs_status 47% / bbs_creation_status 32% / bbs_after_status 17% / bbs_ac_call_status 3% |
| **住所3分割の充足**（店舗Plus） | ✅ address_1/2/3 が**全行100%充足**（post_1/2・tel_1・営業時間も100%）。§5 の分割→city/town/address_detail の**1:1対応が構造的に可能**（実値の意味対応は下記で要確認） |

**残る検証課題**：
- `bbs_status`（後確／制作の両方に使われる）の**内部区別**は、この列だけでは不可。`commodity_type` や
  別フラグでの判別が必要か、サンプルで要確認。
- address_1/2/3 の**各列が「市区／町名／番地」に順当に対応するか**は、実値の目視サンプル（数件）で確定する。

---

## 9. 次段階

- ~~§7（案件238カラム → orders）を、案件CSV・受注フィールド一覧xlsx の精読後に作成~~ ✅ `11-order-field-mapping.md`（Rails版付録A まで完了）
- address 分割ルールの**サンプル検証**（実データ数件で city/town/address_detail の対応を確認）（R7）
- 掲示板の掲示板種別判定ロジックの**サンプル検証**（bbs_*_status のどれが埋まるか実データで確認）（§8-2 で構造検証済み。`inquiry_statuses.code` への変換表作成は R7）
- ETL 実装（rake タスク／`rails runner`・ActiveRecord 経由・Solid Queue ジョブ。`09` §6-2 Rails版）は R7 で着手

---

## 10. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版。グループ/代理店/営業担当/店舗/掲示板の新旧カラム対応表を作成。ヘッダ無しCSV・住所分割・紐づけ復元の課題を抽出（Q-移6〜11）。案件238カラムは次段階 |
| 2026-08-19 | Rails版改訂。対応先を実装名（`agency_groups.id`/`agencies.id`/`stores`/`customer_id`/`orders`）へ更新し「実装状況」列を追加。掲示板の移行先を R4 実装済み `inquiries`/`inquiry_messages` に更新。NOT NULL 制約（`stores.customer_id`・`sales_representatives.agency_id`・`orders.contract_condition_id`・`inquiries.order_id`）に起因する投入順序・受け皿の論点と Q-移19/20 を追加 |
