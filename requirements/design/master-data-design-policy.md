# マスタデータ設計方針 — 専用テーブル / 選択肢マスタ / エンティティマスタの使い分け

> 作成: 2026-08-19（CEO指示により策定）。フェーズ対応: **横断**（R2 実装済み分の追認 ＋ R5/R6/R7 で新規マスタを足す際の判断基準）。
> **📖 まず読むなら `master-data-guide.md`（入口・平易版）**。本書は実装者向けの詳細版です。
> 位置づけ: 「この値は専用テーブルを立てるのか、`OptionGroup`/`OptionValue` に入れるのか」を都度の勘で決めず、
> **判定基準で機械的に決める**ための規約。新しい選択肢・区分値を追加するときは必ず本書の §3 判定フローを通す。
> 突合日 2026-08-19（`db/schema.rb` / `app/models/*` / `app/services/*` の実装実態に基づく）。

---

## 0. 結論（3行）

- **業務ロジックが値を見て分岐するなら → 専用テーブル**（`customer_statuses` のような「コード表」）
- **人が選ぶだけで、システムは中身を解釈しないなら → 選択肢マスタ**（`OptionGroup`/`OptionValue`）
- **それ自身が属性を持ち、他から参照される「モノ」なら → エンティティマスタ**（`products` のような独立テーブル）

---

## 1. 3分類の定義

本プロジェクトの「マスタらしきもの」は、**性質の異なる3種類**に分かれる。同じ「一覧から選ぶ値」に見えても、
**システムがその値をどう扱うか**が決定的に違うため、混同すると設計が破綻する。

| # | 分類 | 実装 | 本質 | 現行の該当 |
|---|---|---|---|---|
| **A** | **状態・区分コード表**（専用テーブル） | 概念ごとに専用テーブル（`customer_statuses` / `order_statuses` / `inquiry_statuses`） | **システムが意味を解釈し、挙動を変える**値。業務ワークフローの状態そのもの | 申込ステータス8値 / 案件ステータス31値 / 問い合わせステータス25値 |
| **B** | **選択肢マスタ**（汎用テーブル） | `option_groups` + `option_values` の2テーブルに全概念を相乗り | **人間が選ぶための語彙**。システムは中身を解釈せず、文字列として保存するだけ | 都道府県47 / 申込者区分3 / 同意状況3 / 事業証明書2 / 高齢者同意書3 / 業務権限証明書3 / はい・いいえ2 ほか（10グループ71値） |
| **C** | **エンティティマスタ**（独立テーブル） | 概念ごとに独立テーブル＋FK | **それ自身が複数の属性を持つ「モノ」**。他テーブルから外部キーで参照される | `products` / `plans` / `production_companies` / `agencies` / `contract_conditions` / `recipient_groups` / `sales_materials` ほか |

### 1-1. A（状態・区分コード表）の特徴

```
customers.status ──(文字列 code)──> customer_statuses.code
                                     ├─ is_system: true の行は削除・code変更が禁止（SystemManagedStatus）
                                     └─ CustomerStatus::CODE_APPLIED / CODE_WITHDRAWN でコードから名指し参照
```

**技術的な指標（現行実装）**:
- 値は対象テーブルの `status` 列に**文字列 code として直接保存**（FK ではない。理由は §4-1）
- モデルバリデーションでマスタ存在を担保: `CustomerStatus.exists?(code: status)` / `OrderStatus.exists?(code: status)`
- **`is_system` フラグ**で「コードが名指しする行」を保護（`SystemManagedStatus` concern。`InquiryStatus` は
  category スコープのため同等ロジックを個別実装）
- **コード側に定数がある**: `CustomerStatus::CODE_APPLIED` / `CODE_WITHDRAWN` / `OrderStatus::CODE_ORDERED`
- **値が業務挙動を左右する**実例:
  - `Customer.active` スコープが `withdrawn` を除外する
  - `Order#assign_default_status` が `0:受注` を初期値に設定する
  - `InquiryRecipientRoute` が `(category, status_code)` をキーに**通知の宛先を決定する**
  - R5 の契約ワークフロー状態機械が遷移条件に使う

### 1-2. B（選択肢マスタ）の特徴

```
OptionGroup(key: "prefecture") ─> OptionValue × 47
                                    │
                                    └─(seed時にコピー)─> FormField.input_options["choices"]
                                                            │
                                                            └─> 画面のセレクトボックス
                                                                 └─> 選ばれた文字列が customers.prefecture 等へ保存
```

**技術的な指標（現行実装）**:
- **汎用2テーブルに全概念が相乗り**（`option_groups.key` で概念を識別）
- **階層を持てる**（`parent_id` / `depth`。都道府県→市区町村のような入れ子に対応。現在は全て depth 0）
- **コード側に定数が無い**＝特定の値を名指しするロジックが存在しない
- 実行時には参照されない: `BridgePlusFormTemplateSeeder` が**seed 時に `FormField.input_options["choices"] へ値をコピー**し、
  申込フォームのバリデーション（`Form::DynamicFormValidator`）はコピーされた choices だけを見る
- 保存先の列は**ただの文字列列**（`customers.prefecture` は `string(20)`。FK ではない）

### 1-3. C（エンティティマスタ）の特徴

- **それ自身が意味のある属性を複数持つ**（`products.name` / `code` / `is_active`、`plans.monthly_fee` …）
- 他テーブルから **FK で参照**される（`orders.plan_id` → `plans.id`）
- **専用の管理画面 CRUD** と Pundit Policy を持つ
- ライフサイクルが業務都合で動く（商材が増える・プランが改定される）

> AとCの違い: **Aは「レコードの状態」、Cは「登場する登場人物・モノ」**。
> `plans` は「どのプランを契約したか」という**関連**であり、`orders.status` は「その案件が今どの段階か」という**状態**。

---

## 2. なぜ分けるのか（混同したときに起きること）

| 誤り | 起きる問題 |
|---|---|
| **状態(A)を選択肢マスタ(B)に入れる** | 管理画面から誰でも値を消せる／リネームできる。`CODE_WITHDRAWN` を消された瞬間に `Customer.active` が壊れ、退会顧客が一覧に出る。`is_system` 保護が効かないため**業務ロジックの前提が運用操作で崩壊する** |
| **単なる語彙(B)を専用テーブル(A)にする** | 「都道府県マスタ」「同意状況マスタ」…とテーブルが際限なく増える。それぞれに migration・モデル・管理画面 CRUD・Policy・spec が必要になり、**得るものが無いのに保守対象だけ増える**（現行10グループ＝テーブル10個分の削減になっている） |
| **エンティティ(C)を選択肢マスタ(B)にする** | 属性を持てない（プランの月額料金をどこに置く？）。FK が張れず参照整合性が保証されない |
| **状態(A)をコード定数なしで運用** | 「この文字列は何を意味するのか」がコードから読めず、値の変更影響が追跡不能になる |

---

## 3. 判定フロー（新しい値を追加するときに必ず通す）

```
Q1. その値は、それ自身が属性を複数持つ「モノ」か？
    （例: 商材＝名前・コード・有効フラグ・販売許可…を持つ）
    YES → 【C. エンティティマスタ】独立テーブル＋FK
    NO  ↓

Q2. システムのコードが、特定の値を名指しして挙動を変えるか？
    （if status == "withdrawn" / スコープの除外条件 / 状態遷移の可否 / 通知の宛先決定 …）
    ※「今は分岐しないが、近いフェーズで分岐する予定」も YES 扱い
    YES → 【A. 状態・区分コード表】専用テーブル＋is_system＋コード定数
    NO  ↓

Q3. 人が画面で選ぶだけで、システムは中身を解釈せず保存するだけか？
    YES → 【B. 選択肢マスタ】OptionGroup / OptionValue に追加（テーブルを増やさない）
    NO  → 設計判断が必要。本書を更新すること
```

### 3-1. Q2 の判定を助ける具体的な問い

以下に**1つでも該当すれば A（専用テーブル）**とする。

- [ ] その値によって**画面遷移・処理分岐**が変わるか？（例: 支払方法がおまとめなら決済画面をスキップ）
- [ ] その値が**スコープの絞り込み条件**になるか？（例: 退会済みを一覧から除外）
- [ ] その値が**次に進める状態を制限する**か？（状態機械の遷移条件）
- [ ] その値によって**通知の宛先・文面が変わる**か？
- [ ] その値が**帳票・CSV・集計の区分**として使われるか？
- [ ] 値が消えたり改名されたら**バグになる**か？（＝`is_system` 保護が要る）

---

## 4. 設計上の決定事項（なぜこの実装なのか）

### 4-1. なぜ状態(A)は FK ではなく文字列 code で持つのか

`customers.status` は `customer_statuses.id` への FK ではなく、`code` 文字列を直接保存している。

**理由**:
1. **R7 データ移行との相性**: 旧システムの案件ステータスは `"10:作業進行中"` のような文字列。code をそのまま採用したことで、
   移行時の値変換が不要になっている（`legacy-research/03` の統廃合マッピングだけで済む）
2. **コード定数との対応が直感的**: `Order::CODE_ORDERED = "0:受注"` がそのまま DB の値と一致し、SQL でもログでも読める
3. **マスタ行の削除耐性**: FK だと `on_delete` の挙動を考える必要があるが、`is_system` 保護＋モデルバリデーションで
   「マスタに存在する code のみ許可」を担保する方式に統一している

**トレードオフ（承知のうえで受容）**: DB レベルの参照整合性が無いため、**モデルを経由しない書き込み（`update_all`・
生SQL・R7のバルクインサート）ではバリデーションが効かない**。R7 の ETL では投入前に必ず変換表で正規化すること。

### 4-2. なぜ選択肢(B)は実行時に参照されず、FormField へコピーされるのか

`BridgePlusFormTemplateSeeder` は OptionValue の値を `FormField.input_options["choices"]` へ**コピー**する。
実行時に `OptionGroup` を引き直してはいない。

**理由**: 申込フォームは**申込時点の選択肢を固定**すべきだから。後から都道府県マスタの表記が変わっても、
過去の申込レコードやフォーム定義が影響を受けない（フォーム定義自体が版管理の役割を持つ）。

**トレードオフ**: マスタを更新しても既存フォームに自動反映されない。反映したい場合は
**フォームビルダーで明示的に更新するか、seeder を再実行する**運用になる（`form-template-mapping.md` §3・
「`input_options.option_group_key` による参照解決」は R6 の任意課題として残っている）。

---

## 5. 現行実装の分類結果（2026-08-19 突合）

### 5-1. A. 状態・区分コード表（専用テーブル）

| テーブル | 件数 | 保存先 | 保護 | コード定数 |
|---|---|---|---|---|
| `customer_statuses`（申込ステータス） | 8 | `customers.status` | `SystemManagedStatus` | `CODE_APPLIED` / `CODE_WITHDRAWN` |
| `order_statuses`（案件ステータス） | 31 | `orders.status` | `SystemManagedStatus` | `CODE_ORDERED` |
| `inquiry_statuses`（問い合わせステータス） | 25 | `inquiries.status` | 個別実装（category スコープのため） | `Inquiry::DEFAULT_STATUS_CODES` |

> 呼称は Q-B（D-8決定）により「申込ステータス」「案件ステータス」「契約ステータス」の3語。
> **「顧客ステータス」は使用禁止語**（2026-08-19 に UI 刷新で表記が巻き戻る事故が発生済み。要注意）。

### 5-2. B. 選択肢マスタ（OptionGroup / OptionValue）

| key | ラベル | 値数 | 判定 |
|---|---|---|---|
| `prefecture` | 都道府県 | 47 | ✅ 適正（システムは中身を解釈しない） |
| `applicant_type` | 申込者区分 | 3 | ✅ 適正（現時点では分岐なし） |
| `consent_status` | 同意状況 | 3 | ⚠️ 要注視（§5-4） |
| `business_proof` | 事業証明書 | 2 | ✅ 適正 |
| `elderly_consent` | 高齢者同意書 | 3 | ⚠️ 要注視（§5-4） |
| `business_auth_doc` | 業務権限証明書 | 3 | ✅ 適正 |
| `yes_no` | はい/いいえ（共通） | 2 | ✅ 適正 |
| ~~`payment_method`~~ | お支払方法 | — | ✅ 2026-08-19 **A へ移行完了**（`payment_methods` 専用テーブル。commit `f819fb2`）。OptionGroup 側は廃止し、残存行はシードで自動削除する（§5-3） |
| ~~`group_key_1` / `group_key_2`~~ | 選択肢グループ1/2 | — | ✅ 2026-08-20 **除去済み**。RSpec の FactoryBot シーケンス（`spec/factories/option_groups.rb`）が生成したキーが実DBへ混入したもので、実データではなかった。ファクトリのキーをテスト専用と分かる名前へ変更し、併せて `BridgePlusFormTemplateSeeder` に残存行の自動削除を実装（`bin/rails db:seed` で消える） |

### 5-3. ✅ `payment_method` は B → A へ移行済み（2026-08-19 完了）

**移行前の状態**: `OptionGroup(key: "payment_method")` の選択肢（預金口座振替 / クレジット）として管理され、
`orders.payment_method`（`string(50)`）に文字列で保存されていた。コード定数は無かった。

**問題**: R5 の **D-P12①** で「申込フォームの支払方法3択（口振／クレカ／おまとめ）に応じて、
**おまとめ選択時はカード登録画面をスキップする**」という**処理分岐**が必要になる（`payment-integration.md` D-P12）。
これは §3-1 の「画面遷移・処理分岐が変わるか？」に該当し、**判定フロー Q2 が YES ＝ A 分類**である。

このまま B のままにすると:
- 管理画面から「クレジット」の表記を変えた瞬間に決済分岐が壊れる（`is_system` 保護が無い）
- 分岐条件をコードに書くとき、比較対象の文字列がマスタと二重管理になる

**✅ 2026-08-19 実施済み（commit `f819fb2`）。以下は実施内容**:
1. `payment_methods` 専用テーブルを新設（`SystemManagedStatus` を include）し、`is_system` で保護する
2. `PaymentMethod::CODE_BANK_TRANSFER` / `CODE_CREDIT` / `CODE_BUNDLED` のコード定数を置く
3. `orders.payment_method` のバリデーションを `PaymentMethod.exists?(code:)` に変更する
4. `BridgePlusFormTemplateSeeder` の OptionGroup `payment_method` は廃止し、FormField の choices は
   専用マスタから生成する
> ※ 簡易案として「OptionGroup のまま `is_system` 相当の保護だけ足す」ことも考えられるが、
> 汎用テーブルに個別保護を後付けすると B の単純さが崩れるため**推奨しない**（採用せず）。

**⚠️ 移行前にシード済みの環境の後始末（2026-08-20 追加対応）**: 上記4は「無ければ作る」投入のため、
昇格より前に `db:seed` を流した環境では
(a) 旧 `OptionGroup(key: "payment_method")` が管理画面の選択肢一覧に残り、
(b) `FormField(payment_method)` の `input_options.choices` が旧ラベル値（`預金口座振替` / `クレジット`）のまま残る、
という2つのズレが発生する。(b) は保存される値が `PaymentMethod.exists?(code:)` を通らず**申込が保存できなくなる**。
`BridgePlusFormTemplateSeeder` に (a) の自動削除と (b) のマスタ再同期を実装したので、
**該当環境は `bin/rails db:seed` を1回流せば解消する**（`MASTER_DERIVED_OPTION_GROUPS` 参照）。

### 5-4. ⚠️ 要注視（現時点は B のままでよいが、業務確定時に再判定）

- **`consent_status`（同意状況）・`elderly_consent`（高齢者同意書）**: 現在は単なる記録用の選択肢だが、
  R5 の重要事項説明チェック（Q-35）で「同意が取れていない案件は契約に進めない」といった**遷移条件になれば A へ移す**。
  `contract-confirmation-docs.md` の重説チェックは専用テーブル（`disclosure_checks`）で持つ設計のため、
  そちらへ統合される可能性もある。**R5 着手時に再判定すること**。

### 5-5. C. エンティティマスタ（参考・分類の確認のみ）

`products` / `plans` / `product_initial_fees` / `product_options` / `production_companies` / `sales_materials` /
`agencies` / `agency_groups` / `contract_conditions` / `recipient_groups` / `notification_templates` /
`form_templates` / `inquiry_recipient_routes` / `ip_allowlist_entries` / `system_roles` / `system_permissions`

いずれも独立した属性を持ち FK で参照される、または専用の管理 UI を持つため C で適正。

---

## 6. 運用ルール

1. **新しい選択肢・区分値を足すときは §3 の判定フローを通す**。判断に迷ったら本書に追記して記録を残す。
2. **B → A への昇格は「業務ロジックが値を見始めた瞬間」に行う**。「今は分岐しないが将来する」なら最初から A にする
   （後から移すとデータ移行と分岐実装が同時に発生して事故りやすい）。
3. **A のテーブルを新設したら必ず**: ①`SystemManagedStatus` を include ②`is_system` で保護すべき行を決める
   ③コード定数を置く ④`StatusSeeder` に既定値を追加 ⑤対象モデルに `exists?(code:)` バリデーションを足す。
4. **A の code は R7 の移行元の値をなるべくそのまま採用する**（§4-1 の理由。値変換を増やさない）。
5. **B に足すときはテーブルを増やさない**。`OptionGroup.key` を足すだけで済ませる。
6. **管理画面から消せてはいけない値には必ず `is_system: true` を立てる**。立て忘れは運用事故に直結する。

---

## 7. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-08-20 | §5-2/§5-3 を実装状況に同期。`payment_method` の B→A 移行完了（commit `f819fb2`）と、開発用ダミー `group_key_1/2` の除去完了を記録 |
| 2026-08-19 | 初版。CEO指示により、専用テーブル（状態・区分コード表）／選択肢マスタ（OptionGroup・OptionValue）／エンティティマスタの3分類と判定フローを定義。現行実装を全件分類し、`payment_method` が R5 の決済分岐（D-P12①）により B→A へ移すべき状態であることを検出（§5-3）。`consent_status`・`elderly_consent` を要注視として記録（§5-4）。開発用ダミー `group_key_1/2` の除去を運用開始前タスクとして記録 |
