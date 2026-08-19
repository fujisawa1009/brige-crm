# 申込フォーム フィールドマッピング設計

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/form-template-mapping.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。フェーズ対応: **R3（申込フォーム。フレームワーク部分は実装済み）／R6（WorkDetail のフォーム組み込み＝旧 Phase 4）**。実装突合日: 2026-08-19（`db/schema.rb`・`app/models/form_field.rb`・`app/services/form/*`・開発DBの FormField 件数を確認）。§2 の個別フィールドと実装の突合結果は末尾 **§9 実装突合表** を参照。

作成日: 2026-05-29（Laravel版）／Rails版改訂: 2026-08-19
対象商材: BRIDGE_PLUS（他商材への横展開前提）

---

## 1. 設計方針

### 1-1. 基本方針

- 申込フォームで収集するフィールドは **「申込時に顧客・営業担当者が決められる情報」に限定** する
- 契約後にスタッフが入力する情報（シリアルID・確認コール記録・計上月など）は購入フォームの対象外（→ §4）
- **単一の信頼できるソース（Rails版）**: Laravel版で計画した `FormTemplateDefinition::FIELDS`（コード定数）は採用せず、
  **DB テーブル `form_templates` 1─* `form_steps` 1─* `form_fields`** がフィールド定義の正となる（03§5「フォーム定義は P2拡張後仕様を初期スキーマに採用」）。
  定義の編集は管理画面のフォームビルダー（`Admin::FormTemplatesController`、ネスト属性で一括保存）で行う。**実装済み（R3）**
- 各フィールドは保存先テーブル・カラムのマッピング（`target_table` / `target_column`）を持ち、
  申込完了トランザクション `Form::ApplicationSubmissionService` がマッピングを動的に読み取って各テーブルへ保存する
  （Laravel版 `processApplication()` のハードコード廃止＝§6-1 は **Rails版では最初から動的マッピングで実装済み**）
- FormTemplate は Product と 1─1（`form_templates.product_id` UNIQUE）。Laravel版メタデータの `product_codes`（商材限定）は
  **テンプレート自体が商材単位のため不要**になった

### 1-2. FormField のメタデータ（実装済みスキーマ `form_fields`）

Laravel版で計画したメタデータ配列は、Rails版では以下のカラム構成として実装済み（`app/models/form_field.rb`・`db/schema.rb`）。

| Laravel版メタデータ | Rails版 `form_fields` カラム | 備考 |
|---|---|---|
| `key` | `field_key` (string, step内一意, `/\A[a-z][a-z0-9_]*\z/`) | |
| `label` | `label` | |
| `target_table` | `target_table` (string, `FormField::TARGET_TABLES = customer / store / order / order_work_detail`) | 決定D により `jasmin_` プレフィックス無しの単数形。`order_work_detail` は Rails版で追加 |
| `target_column` | `target_column` (string) | **ホワイトリスト検証あり**（`FormField.allowed_target_columns_for`。R3見直しレビューで追加）: 対応モデルの全カラムから システム列・belongs_to 外部キー・`encrypts` 列・自動採番列（customer_number / order_number）・業務ステータス列（status）を除外。`order.product_option_ids`（has_many :through の集合idsライター）のみ特例で許可 |
| `input_type` | `field_type` (`FormField::FIELD_TYPES = text / textarea / date / integer / boolean / select / checkbox_group`) | Laravel版の `email` / `tel` → `text`、`number` → `integer`、`radio` → `select`（または `boolean`）、`checkbox` → `checkbox_group` に読み替え。**email / tel の形式検証は未実装**（`validation_rules` は現状 `max_length` のみ）|
| `option_group_key` | **未実装** — 選択肢は `input_options` (jsonb) の `choices`（`[[value, label], ...]`）にインライン保持 | OptionGroup / OptionValue マスタは R2 で実装済みだが FormField からは参照していない（→ §3） |
| `default_required` / `can_toggle` | `required` (boolean) のみ | 「切替可否」の概念は無し（ビルダーで自由に変更可） |
| `product_codes` | 不要（FormTemplate が商材単位） | |
| （Laravel版に無し） | `validation_rules` (jsonb: `max_length`) / `sort_order` / `editable_by_tier` (string[]・`sales_representative` / `agency` / `admin`) / `lock_after_status` (order_statuses.code) | P2拡張後仕様の3次元編集権限。R3 では `sales_representative` tier のみ実際に使用し、`lock_after_status` は `FormField#locked_for?` としてロジックのみ用意（R4/R5 の再編集フロー向け）|

---

## 2. フィールドマッピング一覧

> **Rails版注記（2026-08-19）**: 本節の `target_table` は Rails版では `customer` / `store` / `order`（旧 `jasmin_customers` / `jasmin_stores` / `jasmin_orders`）と読み替える。`input_type` は §1-2 の `field_type` 読替表に従う。**本節の67フィールドは、Rails版では FormField の初期定義（seed / 初期テンプレート）として一切投入されていない**（開発DBの `form_fields` は0件・`db/seeds.rb` に FormTemplate/FormStep/FormField の投入無し）。マッピング先カラムの実在・ホワイトリスト可否・型の突合結果は §9 を参照。

### 2-1. 既存12フィールド（Laravel版で対応済み → Rails版: 保存先カラムは全て実在。FormField 定義は未投入）

| field_key | label | target_table（Rails） | target_column | input_type（→field_type） | option_group_key |
|---|---|---|---|---|---|
| customer_name | お名前（会社名） | customer | name | text | - |
| customer_email | メールアドレス | customer | email | email（→text） | - |
| store_name | 店舗名 | store | store_name | text | - |
| store_name_kana | 店舗名（カナ） | store | store_name_kana | text | - |
| postal_code | 郵便番号 | store | postal_code | text | - |
| prefecture | 都道府県 | store | prefecture | select | prefecture |
| city | 市区町村 | store | city | text | - |
| town | 町名・番地 | store | town | text | - |
| address_detail | 建物名・部屋番号 | store | address_detail | text | - |
| phone_number | 電話番号 | store | phone_number | tel（→text） | - |
| fax_number | FAX番号 | store | fax_number | tel（→text） | - |
| payment_method | お支払方法 | order | payment_method | radio（→select） | payment_method |

### 2-2. orders 既存カラム → フォームフィールドとして追加（Rails版: `orders` に全カラム実在・ホワイトリスト許可。FormField 定義は未投入）

#### 確認コール系

| field_key | label | target_column | input_type | option_group_key |
|---|---|---|---|---|
| confirm_call_preferred_date | 確認コール連絡希望日 | confirm_call_preferred_date | date（※実カラムは string(50)。§9） | - |
| confirm_call_time | 確認コール架電時間 | confirm_call_time | text | - |
| confirm_call_contact_name | 確認コール担当者名 | confirm_call_contact_name | text | - |
| confirm_call_remarks | 確認コール備考 | confirm_call_remarks | text（→textarea 可） | - |

#### 同意・書類系

| field_key | label | target_column | input_type | option_group_key |
|---|---|---|---|---|
| consent_status | 同意状況 | consent_status | select | consent_status ※要定義 |
| consent_rep_age | 同意時 代表者年齢 | consent_rep_age | number（→integer） | - |
| consent_contact_age | 同意時 担当者年齢 | consent_contact_age | number（→integer） | - |
| business_proof | 事業証明書 | business_proof | select | business_proof ※要定義 |
| elderly_consent | 高齢者同意書 | elderly_consent | select | elderly_consent ※要定義 |
| business_auth_doc | 業務権限証明書 | business_auth_doc | select | business_auth_doc ※要定義 |
| paper_address_note | 用紙の送付先住所記載 | paper_address_note | text | - |

#### 設置先住所系（信販用・店舗と異なる場合）

| field_key | label | target_column | input_type | option_group_key |
|---|---|---|---|---|
| finance_postal_code | 設置先郵便番号 | finance_postal_code | text | - |
| finance_prefecture | 設置先都道府県 | finance_prefecture | select | prefecture（既存再利用） |
| finance_city | 設置先市区町村 | finance_city | text | - |
| finance_town | 設置先町名・番地 | finance_town | text | - |
| finance_address_detail | 設置先番地 | finance_address_detail | text | - |
| finance_building | 設置先ビル名 | finance_building | text | - |
| finance_phone | 設置先電話番号 | finance_phone | tel（→text） | - |

#### 追加サービス系

| field_key | label | target_column | input_type | option_group_key |
|---|---|---|---|---|
| plus_applied | Plus申込有無 | plus_applied | radio（→select。§6-3） | yes_no ※要定義 |
| citation_applied | サイテーション申し込み | citation_applied | radio（→select） | yes_no |
| citation_count | サイテーション申し込み数 | citation_count | number（→integer） | - |
| citation_existing_serial | サイテーション既存シリアル | citation_existing_serial | text | - |
| domestic_citation_plan | 国内サイテーションプラン | domestic_citation_plan | text | - |
| citation_plan | サイテーションプラン | citation_plan | text | - |
| s_plan_cms | Sプラン CMS | s_plan_cms | radio（→select） | yes_no |
| owlet_cms | Owlet CMS | owlet_cms | radio（→select） | yes_no |
| onerank_cms | Onerank CMS | onerank_cms | radio（→select） | yes_no |
| external_link_applied | 外部リンク申し込み | external_link_applied | radio（→select） | yes_no |
| external_link_count | 外部リンク申し込み数 | external_link_count | number（→integer） | - |
| external_link_type | 外部リンクの型 | external_link_type | text | - |
| gbp_multilingual | GBPインバウンド多言語対策 | gbp_multilingual | radio（→select） | yes_no |
| language_selection | 言語選択 | language_selection | text | - |
| meo_existing_serial | MEO既存シリアル | meo_existing_serial | text | - |
| infobiz_applied | info Biz申し込み | infobiz_applied | radio（→select） | yes_no |
| meo_premium_applied | MEOプレミアム強化プラン申し込み | meo_premium_applied | radio（→select） | yes_no |
| google_ads_applied | Google広告申し込み | google_ads_applied | radio（→select） | yes_no |
| google_ads_count | Google広告申し込み数 | google_ads_count | number（→integer） | - |
| google_review_display | Google口コミ表示 | google_review_display | radio（→select） | yes_no |
| review_heading | 口コミ表示の見出し名 | review_heading | text | - |
| reservation_system | 予約システム | reservation_system | radio（→select） | yes_no |
| portal_site_applied | ポータルサイト掲載の申し込み | portal_site_applied | radio（→select） | yes_no |
| bridge_migration | Bridge移行 | bridge_migration | radio（→select） | yes_no |
| bridge_migration_order_number | Bridge移行案件番号 | bridge_migration_order_number | text | - |

### 2-3. ~~DBカラムが存在しない → 新規追加が必要~~ → **Rails版: R2 スキーマで全て実装済み**（Column.md 準拠。1件のみ列名が設計と異なる）

#### customers への追加カラム（→ 実装済み。`customer_name_kana` の保存先のみ `contractor_name_kana` に読み替え）

| field_key | label | 新カラム名（設計） | Rails 実カラム | input_type | option_group_key | 備考 |
|---|---|---|---|---|---|---|
| customer_name_kana | 契約者名（カナ） | name_kana | **`contractor_name_kana`** string(255) | text | - | **列名差異**（Column.md §8 に従い実装側が正） |
| applicant_type | 申込者区分 | applicant_type | applicant_type string(20) | select | applicant_type ※要定義 | 法人/個人事業主（Column.md: `法人` / `個人事業主` / `個人`） |
| customer_postal_code | 契約者郵便番号 | postal_code | postal_code string(8) | text | - | 店舗住所と別管理 |
| customer_prefecture | 契約者都道府県 | prefecture | prefecture string(20) | select | prefecture | 店舗住所と別管理 |
| customer_city | 契約者市区町村 | city | city string(50) | text | - | |
| customer_town | 契約者町名・番地 | town | town string(100) | text | - | |
| customer_address_detail | 契約者建物名 | address_detail | address_detail string(200) | text | - | |
| customer_phone | 日中のご連絡先電話番号 | phone | phone string(20) | tel（→text） | - | |
| customer_mobile | 携帯電話番号 | mobile_phone | mobile_phone string(20) | tel（→text） | - | |

#### stores への追加カラム（→ 実装済み）

| field_key | label | 新カラム名 | Rails 実カラム | input_type | option_group_key | 備考 |
|---|---|---|---|---|---|---|
| business_hours_1 | 営業時間1 | business_hours_1 | business_hours_1 string(50) | text | - | 例: 16:00~03:00 |
| business_hours_2 | 営業時間2 | business_hours_2 | business_hours_2 string(50) | text | - | |
| regular_holiday | 定休日 | regular_holiday | regular_holiday string(100) | text | - | |

---

## 3. 事前定義が必要な OptionGroup 一覧

> **Rails版注記**: 現行実装の FormField は OptionGroup を参照せず、select / checkbox_group の選択肢を `input_options.choices` に
> インラインで持つ（`app/views/form/applications/_field_input.html.erb`・`Form::DynamicFormValidator#type_errors`）。
> したがって本節の「OptionGroup key」は、Rails版では **(a) フォームビルダーで `input_options` に選択肢を直接入力する**か、
> **(b) 将来 `input_options.option_group_key` → OptionGroup 参照の解決機構を追加する（未実装・R6候補）** かのどちらかで実現する。
> また `prefecture` / `payment_method` の OptionGroup マスタは Laravel版では「既存」だったが、Rails版では **シーダー未作成**
> （開発DBの `option_groups` は0件・`db/seeds.rb` は権限/ロール/ステータスのみ）。BRIDGE_PLUS テンプレート投入時に併せて用意する。

| OptionGroup key | 用途 | 選択肢案 | 確定状況 | Rails版の状態 |
|---|---|---|---|---|
| `yes_no` | はい/いいえ（共通） | はい / いいえ | **確定** | 未投入。保存先 `orders.*_applied` 等は string(5) のため値は「はい」/「いいえ」等の文字列で保存（§6-3） |
| `applicant_type` | 申込者区分 | 法人 / 個人事業主 | **要確認**（Column.md §8 は `法人`/`個人事業主`/`個人`） | 未投入 |
| `consent_status` | 同意状況 | 同意 / 同意なし / 確認中 | **要確認** | 未投入 |
| `business_proof` | 事業証明書 | あり / なし | **要確認**（Column.md §10 では string(200)「URLや記録」＝自由記述の可能性） | 未投入 |
| `elderly_consent` | 高齢者同意書 | あり / なし / 該当なし | **要確認** | 未投入 |
| `business_auth_doc` | 業務権限証明書 | あり / なし / 該当なし | **要確認** | 未投入 |
| `external_link_type` | 外部リンクの型 | - | **不要（テキスト入力に決定）** | - |
| `language_selection` | 言語選択 | - | **不要（テキスト入力に決定）** | - |
| `citation_plan` | サイテーションプラン | - | **不要（テキスト入力に決定）** | - |
| `domestic_citation_plan` | 国内サイテーションプラン | - | **不要（テキスト入力に決定）** | - |
| `prefecture` | 都道府県 | 全47都道府県 | ~~既存（再利用）~~ Rails版: **シーダー未作成** | 未投入 |
| `payment_method` | お支払方法 | クレジットカード / 口座振替 | ~~既存（再利用）~~ Rails版: **シーダー未作成**（Column.md §10 例: 預金口座振替 / クレジット） | 未投入 |

---

## 4. 契約後スタッフ入力（購入フォーム対象外）

以下は申込フォームには載せない。管理画面の案件編集（`Admin::OrdersController`）で入力する。

> **Rails版注記（要確認）**: 下記カラムは `FormField.allowed_target_columns_for("order")` の**ホワイトリストからは除外されていない**
> （除外対象は外部キー・`encrypts` 列・採番列・status のみ。`billing_password` は `encrypts` により除外済み）。
> つまり「申込フォームに載せない」は現状 **運用ルール止まり**で、フォームビルダー操作者が誤って `serial_id` や `accounting_month` を
> target_column に指定することは機構的には防げない。同様に `customer` 側では Devise/OTP 認証列（`encrypted_password` / `otp_code_digest` /
> `otp_code_expires_at` / `otp_attempts` / `unlock_token` / `locked_at` / `failed_attempts`）と決済会員ID `netmove_member_id`（PII分類C）も
> ホワイトリスト上は許可されている（`encrypts` ではなく Devise 独自の bcrypt 列のため `encrypted_attributes` に含まれない）。
> **認証列の除外は R3 残タスクとして早期対応を推奨**（→ §9-2）。§4 の業務カラム群を除外するかは業務判断（要確認）。

```
serial_id              シリアルID（開通後に発番）
member_id              会員管理ID（バックオフィス付与）
meo_mgmt_number        MEO施策管理番号
toss_up_code           トスアップCD
billing_password       請求パスワード（Rails版: Order#billing_password は encrypts 済み → ホワイトリスト除外済み）
contract_start_date    契約開始日
issued_at              発注日
account_issued_at      アカウント発行日
work_completed_at      作業完了日
contract_sent_at       契約書送付日
inspection_call_*      検収コール関連（inspection_call_history / inspection_call_ng_time / inspection_call_completed_at）
accounting_month       計上月
bridge_accounting_month Bridge計上月
payment_collected_at   決済回収日
payment_doc_confirmed_at 決済書類確認日
elderly_consent_collected_at  高齢者同意書回収日
business_auth_doc_collected_at 業務権限証明書回収日
inspection_call_completed_at  検収確認コール完了日
cancelled_at           キャンセル日
terminated_at          解約日
termination_reason     解約理由
confirm_call_staff_name  確認コール架電担当名（スタッフ名）
confirm_call_notes       確認コール詳細（架電履歴）
sales_mgmt_slip_number   販管売上伝票番号
factor_notes             ファクター回収備考
bundled_billing          おまとめ請求
bundle_target_order_number おまとめ先の案件番号
```

---

## 5. WorkDetail（GBP作業詳細）の扱い

BridgePlus データには GBP 設定に必要な詳細情報が多数含まれている（最寄駅・業種・キーワード・SNSアカウント等）。
これらは `order_work_details` テーブル（`OrderWorkDetail`・Order と 1─1）に保存される。

- **Rails版の実装状況**: `FormField::TARGET_TABLES` に `order_work_detail` が含まれ、`Form::ApplicationSubmissionService#apply_order_work_detail!`
  が「`order_work_detail` を対象とするフィールドが1つでも定義されていれば OrderWorkDetail を生成」する。**フレームワークとしては R3 で組み込み済み**。
- SNS認証情報8カラム（`system_account_id/pass`・`google_account_id/pass`・`instagram_id/pass`・`facebook_id/pass`）は `encrypts` 対象のため
  **ホワイトリストから自動除外**され、申込フォームには載せられない（`pii-handling-rules.md` §1 分類B。R3見直しレビューでの是正）。
- 個別フィールド（最寄駅・業種・キーワード等 約60カラム）を BRIDGE_PLUS フォームへ組み込むかどうかは、Laravel版どおり
  **旧 Phase 4 → R6（運用強化）扱い**とし、本書 §7 決定事項 8 で範囲を確定してから投入する。

```
対象フィールド例:
ビジネスプロフィールURL / 最寄駅 / 道順 / 駐車場 / 業種
キーワード（地域・業種・通称エリア）/ Google ビジネスプロフィール URL
Instagram ID/PASS / Facebook ID/PASS（← フォーム対象外・encrypts 列）/ バリアフリー / Wi-Fi
開業日 / 従業員数 / 資本金 など
```

---

## 6. 懸念事項

### 6-1. processApplication() の動的マッピング → **Rails版: 実装済み**

Laravel版の懸念（12フィールドのハードコード）は、Rails版では `Form::ApplicationSubmissionService` が最初から動的マッピングで実装されている。
Application#form_data（jsonb・field_key => 回答値）を FormField 定義に従って Customer → Store → Order（→ OrderWorkDetail）へ
1トランザクションで反映し、完了時に `form_data` を空にする（R3見直しレビュー: 平文残存対策）。

```ruby
# app/services/form/application_submission_service.rb（要旨）
def apply_attributes!(record, target_table)
  fields_for(target_table).each do |field|
    next unless @application.form_data.key?(field.field_key)
    record.public_send("#{field.target_column}=", cast_value(field, @application.form_data[field.field_key]))
  end
end
# cast_value: integer → Integer(value) / date → Date.parse / boolean → ActiveModel::Type::Boolean / checkbox_group → Array
```

request spec: `spec/requests/form/applications_spec.rb`（正常系: Customer+Store+Order+OrderOption 生成・メール・監査ログ／異常系: 契約条件未設定・Order バリデーション失敗時のロールバック）。

### 6-2. customers の住所フィールド重複 → **Rails版: 解消**

`customers` に `postal_code` / `prefecture` / `city` / `town` / `address_detail` / `phone` / `mobile_phone` / `contractor_name_kana` /
`applicant_type` が R2 スキーマで実装済み（Column.md §8 準拠）。契約者住所は customers、設置先（信販）住所は `orders.finance_*` と役割分担が確定した。
§7 決定事項 5 は「customers に新カラム」で着地済み。

### 6-3. yes_no ラジオの値の持ち方 → **要決定（Rails版で論点が変わった）**

Laravel版では「boolean 型カラム」前提だったが、Rails版（Column.md 準拠）では `orders.plus_applied` / `citation_applied` / `s_plan_cms` 等は
**string(5)** カラムである。現行実装で `field_type: boolean` を string 列にマッピングすると、ActiveModel の型変換により
**`"t"` / `"f"` が保存される**（`Order.new(plus_applied: true).plus_applied #=> "t"` を確認済み）。表示・CSV出力・移行データ（旧システム値）との整合を考えると、
`field_type: select` ＋ `input_options.choices = [["はい","はい"],["いいえ","いいえ"]]`（または移行元の値表記）を使うのが妥当。

**要決定:** string(5) 列に入れる値の表記（`はい`/`いいえ` vs `有`/`無` vs `1`/`0`）。R7 移行マッピング（`legacy-research/11`）の旧値表記と揃えること。

### 6-4. number 型フィールドの保存 → **Rails版: 実装済み**

`field_type: integer` は `Form::DynamicFormValidator`（`Integer(value)` で形式検証）と `ApplicationSubmissionService#cast_value` でキャストされる。

### 6-5. step-n.vue のフォームバインディング → **Rails版: 該当なし（解消）**

Hotwire + ERB（決定B）のため Vue の `useForm` 初期値問題は存在しない。`app/views/form/applications/show_step.html.erb` が
`FormStep#form_fields`（`editable_by(sales_representative)` に絞ったもの）を `_field_input.html.erb` で動的に描画し、
クライアント側は Stimulus `dynamic_form_controller.js`（required 属性の即時フィードバック）、サーバ側は `Form::DynamicFormValidator` の二重バリデーション。

### 6-6. 【Rails版で新規】email / tel の形式検証が無い

`field_type` に email / tel が無く、`validation_rules` も `max_length` のみのため、`customer_email`（`customers.email` は UNIQUE index・マイページのログインID）に
不正な形式が入りうる。マイページ（Devise Customer スコープ）のログインIDとして使う以上、**`validation_rules.format`（email / tel / postal_code）の追加を R3 残タスクとして推奨**。

---

## 7. 決定が必要な事項

| # | 事項 | 選択肢 | 優先度 | Rails版状態（2026-08-19） |
|---|---|---|---|---|
| 1 | `yes_no` OptionGroup の選択肢ラベル | ~~「申し込む/申し込まない」か「はい/いいえ」か~~ **パターンA「はい/いいえ」に決定** | ~~高~~ 完了 | ラベルは確定。**保存値の表記**は §6-3 で再度要決定 |
| 2 | `citation_plan` / `domestic_citation_plan` の実際の選択肢 | ~~現行システムの値を確認~~ **テキスト入力（自由記述）に決定** | ~~高~~ 完了 | `field_type: text` |
| 3 | `external_link_type` の選択肢 | ~~ストック型/フロー型？~~ **テキスト入力（自由記述）に決定** | ~~高~~ 完了 | 同上 |
| 4 | `language_selection` の選択肢 | ~~英語のみ？多言語対応？~~ **テキスト入力（自由記述）に決定** | ~~高~~ 完了 | 同上 |
| 5 | 契約者住所の保持先 | ~~customers に新カラム vs orders.finance_* 流用~~ → **customers に新カラム（R2 実装済み）** | ~~高~~ 完了 | §6-2 |
| 6 | boolean フィールドの radio value | ~~`1`/`0` vs `true`/`false` vs `yes`/`no`~~ → string(5) 列に入れる文字列表記（`はい`/`いいえ` 等） | 中 | **未決**（§6-3。R7 移行元の値表記と要整合） |
| 7 | `consent_status` / `business_proof` 等の選択肢 | 現行運用での値を確認 | 中 | **未決** |
| 8 | WorkDetail フィールドを旧 Phase 4（→R6）として切り出す範囲の確定 | GBP作業詳細全体か一部か | 低 | **未決**（機構は R3 で対応済み。encrypts 8列は対象外） |
| 9 | 【新規】BRIDGE_PLUS 初期テンプレート（§2 の67フィールド）の投入手段 | (a) フォームビルダーで手入力（運用データ）／(b) `db/seeds` or rake タスクで初期投入（コード管理）／(c) テンプレートの CSV/JSON インポート機能を追加 | 高 | **未決**（§9-1。R3 の完了条件「動的マッピングで動作」は満たすが、実商材のテンプレートが存在しない） |
| 10 | 【新規】§4 の契約後スタッフ入力カラムをホワイトリストから機構的に除外するか | 運用ルールのまま／`FormField` に業務除外リストを追加 | 中 | **未決**（§4 注記。Devise/OTP 認証列の除外は業務判断を待たず対応推奨） |

---

## 8. 実装フェーズ

```
Phase 3（Laravel。→ Rails版 R3）: マルチステップフォームビルダー ← 実装済み（R3）

Phase 3.5（Laravel計画 → Rails版 R3 での対応状況）:
  Step 1: FormTemplateDefinition に target_table / target_column を追加      → 済（form_fields スキーマ）
  Step 2: processApplication() を動的マッピング方式に書き換え                → 済（Form::ApplicationSubmissionService）
  Step 3: 決定事項 1〜7 を確定                                              → 1〜5 済／6・7 未決（§7）
  Step 4: customers / stores の新カラムマイグレーション                     → 済（R2 スキーマ）
  Step 5: OptionGroup シーダー追加                                          → 未（prefecture / payment_method / yes_no 等のシーダー無し。§3）
  Step 6: FormTemplateDefinition に BRIDGE_PLUS フィールドを追加            → 未（FormField 初期定義ゼロ。§9-1・§7-9）
  Step 7: step-n.vue のフォームバインディングを動的化                       → 不要（ERB 動的描画で解消。§6-5）
  Step 8: フォームビルダーで BRIDGE_PLUS テンプレート設定                   → 未（Step 6 と同じ。投入手段を §7-9 で決定）

Phase 4（将来 → Rails版 R6）:
  WorkDetail（GBP作業詳細）フィールドの購入フォームへの組み込み（機構は済・個別フィールド投入は未）
  Order 管理系フィールドの管理画面での入力対応（Admin::OrdersController で R2 実装済み）
```

---

## 9. 実装突合表（2026-08-19）

突合対象・方法:
- 設計側: 本書 §2 の 67 フィールド（2-1: 12 / 2-2: 43 / 2-3: 12。※04 R3要確認・review-05 §3 が「155項目」としているのは §2（67）＋§4（26）＋§5 例示等を合算した概数と思われ、field_key 単位の実数は **67**）
- 実装側: `db/schema.rb`（customers / stores / orders の実カラム・型）、`FormField.allowed_target_columns_for`（ホワイトリスト。`rails runner` で実行して取得）、
  FormField 初期定義（`db/seeds.rb`・`spec/factories`・開発DB `form_fields` テーブル）
- 判定: **A** = 保存先カラム実在・ホワイトリスト許可・FormField 定義未投入 ／ **B** = 保存先カラム名が設計と異なる（読み替え要）／ **C** = 保存先カラム無し（要マイグレーション）

### 9-1. 集計

| 判定 | 件数 | 内訳 |
|---|---|---|
| A: 列あり・定義未投入 | **66** | customer 10 / store 12 / order 44 |
| B: 列名差異（読み替えで対応可） | **1** | `customer_name_kana` → 設計 `customers.name_kana` は無く、実装は `contractor_name_kana` |
| C: 列無し（要マイグレーション） | **0** | — |
| **未反映フィールド（FormField 定義として存在しない）** | **67 / 67（全件）** | BRIDGE_PLUS 用 FormTemplate / FormStep / FormField は seed・開発DBとも 0 件。フレームワーク（動的マッピング）は実装済みだが、実商材の定義データが未投入 |

補足（型・入力種別の読み替えが必要なもの。判定 A の内数）:
- `radio`（15件: `payment_method` ＋ yes_no 系14件）→ `select`。yes_no 系の保存先は string(5) のため **`boolean` を使うと `"t"/"f"` が入る**（§6-3）
- `tel`（5件）/ `email`（1件）→ `text`（形式検証なし。§6-6）
- `number`（5件）→ `integer`
- `date`（1件: `confirm_call_preferred_date`）→ 保存先が string(50) のため Date が文字列 `"YYYY-MM-DD"` として保存される（動作はするが型不一致。Column.md 準拠のため実装を正とする）
- `select`（8件）→ OptionGroup 参照ではなく `input_options.choices` にインライン定義（§3）

### 9-2. 突合で判明した要対応・要確認（04 反映用）

| # | 内容 | 区分 | 推奨フェーズ |
|---|---|---|---|
| 1 | BRIDGE_PLUS 初期テンプレート（67フィールド）の投入手段の決定と投入（§7-9）。併せて OptionGroup（prefecture / payment_method / yes_no ほか）のシーダー | 未実装 | R3 残（R5 着手前に決定・投入。運用開始の前提） |
| 2 | `FormField.allowed_target_columns_for("customer")` が Devise/OTP 認証列（`encrypted_password` `otp_code_digest` `otp_code_expires_at` `otp_attempts` `unlock_token` `locked_at` `failed_attempts`）と `netmove_member_id`（PII 分類C）を許可している。`SYSTEM_COLUMNS` 相当の除外リストへ追加を推奨（`spec/models/form_field_spec.rb` にケース追加） | セキュリティ（要対応） | R3 残・優先度高 |
| 3 | §4 契約後スタッフ入力カラム（`serial_id` `accounting_month` 等）のホワイトリスト除外要否（§7-10） | 要確認（業務判断） | R3 残・中 |
| 4 | yes_no 系 string(5) 列の保存値表記（§6-3・§7-6）。R7 移行元の値と整合させる | 要確認（業務） | R3/R7 |
| 5 | `validation_rules` への format 検証（email / tel / postal_code）追加（§6-6） | 未実装 | R3 残・中 |
| 6 | `input_options.option_group_key` → OptionGroup 参照の解決機構（§3 注記 (b)）。インライン choices の二重管理を避けたい場合のみ | 未実装（任意） | R6 |
| 7 | WorkDetail 個別フィールドのフォーム組み込み範囲（§5・§7-8） | 要確認 | R6 |

### 9-3. フィールド別突合表（67件）

| # | §2 | field_key | 設計 target（Rails読替） | schema.rb 実カラム | 実装 field_type 読替 | 選択肢/OptionGroup | ホワイトリスト | FormField定義（seed/DB） | 判定 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 2-1 | `customer_name` | `customer.name` | name string(255) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 2 | 2-1 | `customer_email` | `customer.email` | email string(255) | text（※形式検証なし） | - | 許可 | 無し | A: 列あり・定義未投入 |
| 3 | 2-1 | `store_name` | `store.store_name` | store_name string(255) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 4 | 2-1 | `store_name_kana` | `store.store_name_kana` | store_name_kana string(255) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 5 | 2-1 | `postal_code` | `store.postal_code` | postal_code string(8) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 6 | 2-1 | `prefecture` | `store.prefecture` | prefecture string(20) | select（input_options.choices） | prefecture | 許可 | 無し | A: 列あり・定義未投入 |
| 7 | 2-1 | `city` | `store.city` | city string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 8 | 2-1 | `town` | `store.town` | town string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 9 | 2-1 | `address_detail` | `store.address_detail` | address_detail string(200) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 10 | 2-1 | `phone_number` | `store.phone_number` | phone_number string(20) | text（※形式検証なし） | - | 許可 | 無し | A: 列あり・定義未投入 |
| 11 | 2-1 | `fax_number` | `store.fax_number` | fax_number string(20) | text（※形式検証なし） | - | 許可 | 無し | A: 列あり・定義未投入 |
| 12 | 2-1 | `payment_method` | `order.payment_method` | payment_method string(50) | select（input_options.choices） | payment_method | 許可 | 無し | A: 列あり・定義未投入 |
| 13 | 2-2 | `confirm_call_preferred_date` | `order.confirm_call_preferred_date` | confirm_call_preferred_date string(50) | date（※列は string。Date→文字列で保存） | - | 許可 | 無し | A: 列あり・定義未投入 |
| 14 | 2-2 | `confirm_call_time` | `order.confirm_call_time` | confirm_call_time string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 15 | 2-2 | `confirm_call_contact_name` | `order.confirm_call_contact_name` | confirm_call_contact_name string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 16 | 2-2 | `confirm_call_remarks` | `order.confirm_call_remarks` | confirm_call_remarks text | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 17 | 2-2 | `consent_status` | `order.consent_status` | consent_status string(20) | select（input_options.choices） | consent_status ※要定義 | 許可 | 無し | A: 列あり・定義未投入 |
| 18 | 2-2 | `consent_rep_age` | `order.consent_rep_age` | consent_rep_age integer | integer | - | 許可 | 無し | A: 列あり・定義未投入 |
| 19 | 2-2 | `consent_contact_age` | `order.consent_contact_age` | consent_contact_age integer | integer | - | 許可 | 無し | A: 列あり・定義未投入 |
| 20 | 2-2 | `business_proof` | `order.business_proof` | business_proof string(200) | select（input_options.choices） | business_proof ※要定義 | 許可 | 無し | A: 列あり・定義未投入 |
| 21 | 2-2 | `elderly_consent` | `order.elderly_consent` | elderly_consent string(5) | select（input_options.choices） | elderly_consent ※要定義 | 許可 | 無し | A: 列あり・定義未投入 |
| 22 | 2-2 | `business_auth_doc` | `order.business_auth_doc` | business_auth_doc string(5) | select（input_options.choices） | business_auth_doc ※要定義 | 許可 | 無し | A: 列あり・定義未投入 |
| 23 | 2-2 | `paper_address_note` | `order.paper_address_note` | paper_address_note string(200) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 24 | 2-2 | `finance_postal_code` | `order.finance_postal_code` | finance_postal_code string(8) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 25 | 2-2 | `finance_prefecture` | `order.finance_prefecture` | finance_prefecture string(20) | select（input_options.choices） | prefecture（既存再利用） | 許可 | 無し | A: 列あり・定義未投入 |
| 26 | 2-2 | `finance_city` | `order.finance_city` | finance_city string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 27 | 2-2 | `finance_town` | `order.finance_town` | finance_town string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 28 | 2-2 | `finance_address_detail` | `order.finance_address_detail` | finance_address_detail string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 29 | 2-2 | `finance_building` | `order.finance_building` | finance_building string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 30 | 2-2 | `finance_phone` | `order.finance_phone` | finance_phone string(20) | text（※形式検証なし） | - | 許可 | 無し | A: 列あり・定義未投入 |
| 31 | 2-2 | `plus_applied` | `order.plus_applied` | plus_applied string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no ※要定義 | 許可 | 無し | A: 列あり・定義未投入 |
| 32 | 2-2 | `citation_applied` | `order.citation_applied` | citation_applied string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 33 | 2-2 | `citation_count` | `order.citation_count` | citation_count integer | integer | - | 許可 | 無し | A: 列あり・定義未投入 |
| 34 | 2-2 | `citation_existing_serial` | `order.citation_existing_serial` | citation_existing_serial string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 35 | 2-2 | `domestic_citation_plan` | `order.domestic_citation_plan` | domestic_citation_plan string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 36 | 2-2 | `citation_plan` | `order.citation_plan` | citation_plan string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 37 | 2-2 | `s_plan_cms` | `order.s_plan_cms` | s_plan_cms string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 38 | 2-2 | `owlet_cms` | `order.owlet_cms` | owlet_cms string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 39 | 2-2 | `onerank_cms` | `order.onerank_cms` | onerank_cms string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 40 | 2-2 | `external_link_applied` | `order.external_link_applied` | external_link_applied string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 41 | 2-2 | `external_link_count` | `order.external_link_count` | external_link_count integer | integer | - | 許可 | 無し | A: 列あり・定義未投入 |
| 42 | 2-2 | `external_link_type` | `order.external_link_type` | external_link_type string(20) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 43 | 2-2 | `gbp_multilingual` | `order.gbp_multilingual` | gbp_multilingual string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 44 | 2-2 | `language_selection` | `order.language_selection` | language_selection string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 45 | 2-2 | `meo_existing_serial` | `order.meo_existing_serial` | meo_existing_serial string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 46 | 2-2 | `infobiz_applied` | `order.infobiz_applied` | infobiz_applied string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 47 | 2-2 | `meo_premium_applied` | `order.meo_premium_applied` | meo_premium_applied string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 48 | 2-2 | `google_ads_applied` | `order.google_ads_applied` | google_ads_applied string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 49 | 2-2 | `google_ads_count` | `order.google_ads_count` | google_ads_count integer | integer | - | 許可 | 無し | A: 列あり・定義未投入 |
| 50 | 2-2 | `google_review_display` | `order.google_review_display` | google_review_display string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 51 | 2-2 | `review_heading` | `order.review_heading` | review_heading string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 52 | 2-2 | `reservation_system` | `order.reservation_system` | reservation_system string(50) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 53 | 2-2 | `portal_site_applied` | `order.portal_site_applied` | portal_site_applied string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 54 | 2-2 | `bridge_migration` | `order.bridge_migration` | bridge_migration string(5) | select（列は string→ boolean型だと "t"/"f" が入る。§6-3） | yes_no | 許可 | 無し | A: 列あり・定義未投入 |
| 55 | 2-2 | `bridge_migration_order_number` | `order.bridge_migration_order_number` | bridge_migration_order_number string(20) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 56 | 2-3 | `customer_name_kana` | `customer.name_kana` | **無し**（→ `contractor_name_kana` string(255)） | text | - | 許可 | 無し | **B: 列名差異**（設計 `name_kana` → 実装 `contractor_name_kana` に読み替え） |
| 57 | 2-3 | `applicant_type` | `customer.applicant_type` | applicant_type string(20) | select（input_options.choices） | applicant_type ※要定義 | 許可 | 無し | A: 列あり・定義未投入 |
| 58 | 2-3 | `customer_postal_code` | `customer.postal_code` | postal_code string(8) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 59 | 2-3 | `customer_prefecture` | `customer.prefecture` | prefecture string(20) | select（input_options.choices） | prefecture | 許可 | 無し | A: 列あり・定義未投入 |
| 60 | 2-3 | `customer_city` | `customer.city` | city string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 61 | 2-3 | `customer_town` | `customer.town` | town string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 62 | 2-3 | `customer_address_detail` | `customer.address_detail` | address_detail string(200) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 63 | 2-3 | `customer_phone` | `customer.phone` | phone string(20) | text（※形式検証なし） | - | 許可 | 無し | A: 列あり・定義未投入 |
| 64 | 2-3 | `customer_mobile` | `customer.mobile_phone` | mobile_phone string(20) | text（※形式検証なし） | - | 許可 | 無し | A: 列あり・定義未投入 |
| 65 | 2-3 | `business_hours_1` | `store.business_hours_1` | business_hours_1 string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 66 | 2-3 | `business_hours_2` | `store.business_hours_2` | business_hours_2 string(50) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
| 67 | 2-3 | `regular_holiday` | `store.regular_holiday` | regular_holiday string(100) | text | - | 許可 | 無し | A: 列あり・定義未投入 |
