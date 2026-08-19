# 決済連携 設計書

> **Rails版改訂: 2026-08-19。** 旧Laravelプロジェクト（`boilerplate-vue-env/laravel/requirements/design/payment-integration.md`）を
> brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。**フェーズ対応: R5（契約フロー・決済。P3-1/P3-2 相当）**。
> 突合日 2026-08-19 時点の実装状況: **決済系（`payment_transactions` / `payment_transaction_logs` / APIクライアント / 状態機械 / ret_url 受け口）は未実装（R5）**。
> `customers.netmove_member_id` / `netmove_registered_at`、`orders.payment_method` / `payment_collected_at` / `payment_doc_confirmed_at` /
> `finance_*`（信販9カラム）/ `bundled_billing` / `bundle_target_order_number`、`customers.consolidated_billing` は **R2 実装済み**（`db/schema.rb`）。
> Laravel固有記述（Horizon・`$tries`・`VerifyCsrfToken`・Eloquentモデル名・`../development-plan.md` 参照）は Rails 版へ読み替え、
> 業務要件・決定事項（D-P1〜D-P12）・未決論点（§8）・テスト用マーチャント情報は原文のまま保持した。
> 04 の R5着手前チェックリスト（Q-25〜27・Q-35〜39）との対応は §8 に付記。

> 作成日: 2026-07-24 ／ **改訂: 2026-07-27（導入ガイド全文読了・現行キャプチャ精査を反映）** ／ Rails版改訂: 2026-08-19
> ステータス: **API仕様読了済み（ネットムーブ）** → `legacy-research/02-payment-netmove.md`
> 対象フェーズ: `../development-plan.md` P3-1 / P3-2（クリティカルパス）＝ **`04-rails-implementation-plan.md` R5**
> 関連: `basic-design.md` §7（決済連携）・§6（申込登録） / `remaining-tasks.md` 1-3（削除済み・旧Laravel側に残存。代替＝04 R5節） /
> `03-rails-architecture-proposal.md` §2「状態機械」「キュー」「監査ログ」・§5「決済（PaymentTransaction）は状態機械・ログテーブル含め忠実移植」

---

## 0. 本書の位置づけ

本システム最大級の作業領域。**外部事業者（ネットムーブ）との連携・法務確認・セキュリティ要件**が絡む。

> **重要な進展（2026-07-24）**：決済API仕様は資料内に存在した（ネットムーブ社「3Dセキュア対応
> EC決済API 導入ガイド」）。W-1 は実質解消。詳細は `legacy-research/02`。
> 本書 §4 の設計原則は、受領した実仕様と**完全に一致していた**。

> **重要な訂正（2026-07-27）**：導入ガイド全23ページの読了と、現行運用のテスト実施
> キャプチャ（`決済カード登録APIフロー.xlsx`）の精査により、以下が判明した。
> 詳細は `legacy-research/02` §0・§6。
>
> 1. **現行方式もネットムーブ側ページでカード入力している**（自社画面ではない）。
>    → 移行は「**URLとパラメータの差し替え＋3Dセキュア対応**」の範囲。作り直しではない。
>    → PCI DSS 対象化リスク（R-4）は**元から顕在化していない**。
> 2. **与信と売上は別ステップ**。現行の1円与信では売上が立っていない。
>    **毎月の売上処理（継続課金）の手段がガイドに記載されておらず、本書最大の未確定事項**。
> 3. **ret_url に処理結果コードが返らない**。照会API・Webhook の記載もなく、
>    §4-3「サーバ間で確定」の**実現手段が未提供**。
> 4. **3Dセキュア認証項目が2025年10月から必須化済み**（§4-7 を新設）。

> **Rails版での位置づけ（2026-08-19）**：03§1-3「未実装機能（契約フロー・決済連携）は後付けではなく最初から
> スキーマ・設計に織り込む」に基づき、R2 で `netmove_member_id` 等の**保持先カラムは先行実装済み**。
> 決済処理本体（本書 §4〜§6）は R5 で新規実装する。R5 の着手条件は 04「R5着手前チェックリスト」（Q-25〜27・Q-35〜39）。

---

## 1. 共有をお願いしたい情報（チェックリスト）

| # | 項目 | 状態 |
|---|---|---|
| I-1 | サービス名・事業者名 | ✅ **ネットムーブ株式会社**（管理画面は USEN FinTech ブランド） |
| I-2 | API 仕様書 | ✅ **全文読了**（導入ガイド Ver 1.0.5・全23ページ） |
| I-3 | 連携方式 | ✅ **リダイレクト型**（checkout初期化→決済画面遷移）。**新旧とも同方式** |
| I-4 | テスト環境の有無・接続情報 | ❌ **検証専用環境は無い模様**（ガイド6.1「テストはお手持ちの商用クレジットカードをお使いください」）。必要なのは**開通処理とHMACキー** → 依頼 E-1 |
| I-5 | 認証方式 | ✅ HMAC-SHA256 チェックコード（送信時と ret_url 検証時で**生成データが異なる**） |
| I-6 | Webhook（結果通知） | ❌ **ガイドに記載なし** → 依頼 C-3 |
| I-7 | 決済結果の照会API | ❌ **ガイドに記載なし**。提供APIは `/checkout` の1本のみ → 依頼 C-2。代替候補＝管理画面「取引履歴一括ダウンロード」（依頼 C-4） |
| I-8 | 課金モデル | ✅ **継続課金・月額**（`legacy-research/07`） |
| I-9 | 対応ブランド | ✅ VISA/Master/JCB/AMEX/Diners（Discover・銀聯 非対応） |
| I-10〜15 | 現行運用（フロー・失敗時運用・件数） | 一部判明（§2） |
| I-16 | 支払方法の種類 | クレカ / 口座振替（信販 finance_* あり） |
| **I-17** | **与信後の売上処理（継続課金）の手段** | ✅ **方式判明（決定者情報 2026-07-27）：ファイル連携**。TBSSがネットムーブから会員データを取得 → 請求データ（誰に・いくら）を作成 → ネットムーブへ共有して引き落としを依頼する月次運用。**残る未確認＝ファイルレイアウト・受け渡し経路・締切・結果（成否）の返却方法** → 依頼 A 群を仕様確認に転換 |
| **I-18** | **決済成否の判定方法** | ❌ ret_url に結果コードが含まれない → 依頼 C-1（＝04 **Q-38**） |
| **I-19** | **受注コードの桁数（11 or 12）** | ⬜ ガイド内で記述が矛盾（`legacy-research/02` §4-3）→ 依頼 D-1（＝04 **Q-37**） |
| **I-20** | **移行時の既存カード情報の引き継ぎ** | ⬜ 引き継げない場合、既存顧客全件の再登録が必要 → 依頼 B-3。決定者判断「引き継がれる前提」（`netmove-card-migration.md` §0） |
| **I-21** | **自社サイトコード** | ✅ **S084**（キャプチャより）。継続利用可否は要確認 → 依頼 B-2 |

---

## 2. 現時点で判明していること

### 2-1. 現行フロー

```
仮申し込み → 外部決済リンクへ遷移 → 顧客がカード入力（外部サイト）
  → 新システムへリダイレクト → 外部決済の発行IDを保持
```
→ **リダイレクト型**でカード情報が自システムを通らない。§4-1 の非保持要件を満たす構造。

### 2-2. 申込フロー内での位置づけ（basic-design §6）

```
営業ログイン → 商品選択 → 顧客が情報入力 → クレカ登録 ← 本書の対象
  → 申込確認メール → 重要事項説明チェック → 契約確認メール
```
> 署名は支払方法に関わらず必須（クレカ登録を挟むかの違いのみ）。

> **Rails版・現行R3実装との対応（2026-08-19）**：「営業ログイン〜顧客が情報入力」は
> `Form::SessionsController` / `Form::OtpsController` / `Form::ApplicationsController`（`form/applications/:token/steps/:n`）
> として **R3 実装済み**。`POST form/applications/:token/complete`（`#submit`）で `Form::ApplicationSubmissionService` が
> **Customer / Store / Order（+OrderWorkDetail）を1トランザクションで作成**し `applications.status = completed` にする。
> したがって Rails 版の決済ステップは **「Order 作成後（= `order_number` と顧客が確定した後）」に差し込む**のが自然で、
> `jutyu_cd` の採番と `member_id`（`customers.netmove_member_id`）の発行/参照が可能になる。
> 「クレカ登録が未完了の Order をどう扱うか（`orders.status` の初期値・contract_status）」は R5 の契約ワークフロー
> 状態機械（P3-4）と同時に決める（**未実装・R5**）。

### 2-3. 既存の実装状況

`orders.payment_method`・`payment_collected_at`・`payment_doc_confirmed_at`・`finance_*`（信販9カラム）
は**業務記録用**（旧 `jasmin_orders.*`。決定Dにより `Order` モデル。**R2 実装済み**、`Admin::OrdersController` の
permit 対象）。決済連携処理（APIクライアント・トランザクション記録・状態管理）は**未実装（R5）**。

| 項目 | Rails版の実装状況（2026-08-19 `db/schema.rb` 突合） |
|---|---|
| `customers.netmove_member_id` string(50) / `netmove_registered_at` date | ✅ R2 実装済み（保持先。D-P10「顧客単位」と整合） |
| `customers.consolidated_billing` boolean / `orders.bundled_billing` string(5) / `orders.bundle_target_order_number` string(20) | ✅ R2 実装済み（D-P12 おまとめ請求の保持先。**申込フォームでの3択分岐UIは未実装・R5**） |
| `customers.sms_mobile_number` / `mobile_phone` / `email` | ✅ R2 実装済み（§4-7 3Dセキュア項目の転用元。`legacy-research/02` C-j） |
| `orders.member_id` string(20) | ✅ R2 実装済み。**ただしこれは「会員管理ID（請求ポータル系・英字1+数字9桁）」でありネットムーブ会員IDとは別物**（`netmove-card-migration.md` §2-4）。混同しないこと |
| `payment_transactions` / `payment_transaction_logs` | ❌ 未実装（R5。§5） |
| 決済専用キュー（Solid Queue） / `Payment::*` Service Object / ret_url 受け口 | ❌ 未実装（R5。§4-2・§4-9・§6） |
| `SequenceCounter`（PostgreSQL 単一UPSERTでアトミック採番） | ✅ R2 実装済み（`customer_number` / `order_number` / `inquiry_number` で使用中）。**`jutyu_cd` 下位7桁の採番にも流用する**（`netmove-card-migration.md` §6-3） |
| `Auditable` concern / `AuditLog` | ✅ R0 実装済み（管理者操作の監査に流用。§4-5） |
| `ActiveRecord::Encryption`（`encrypts`） | ✅ R2 で `orders.billing_password` / `order_work_details.*` に適用済み。決済側で秘匿値を持つ場合（現状は想定なし。会員ID・下4桁は秘匿値ではない）も同機構を使う |

---

## 3. 決定事項

| # | 論点 | 決定 |
|---|---|---|
| D-P1 | 連携方式 | **リダイレクト型に確定**（ネットムーブ checkout）。決定者確認済み 2026-07-27。自社画面でカード情報を受け取る方式は**そもそも提供されていない**（提供APIは `/checkout` の1本のみ） |
| D-P2 | 支払方法の種類 | クレカ＋口座振替（信販の扱いは Q-26） |
| D-P3 | カード情報の保持方針 | **非保持・非通過**（会員ID・ブランド・上下4桁・有効性結果のみ） |
| D-P4 | 有効性チェックのタイミング | 会員登録時に**1円与信** |
| D-P5 | 決済失敗時のハンドリング | 未定（§4-4） |
| D-P6 | 二重課金の防止 | **冪等キー方式** |
| D-P7 | 結果確定の判定 | **ret_url + サーバ間確定**（※**確定手段が未提供**。I-18/C-1 の回答待ち＝04 Q-38） |
| **D-P8** | **与信と売上の分離** | **2段階**として設計する。①会員登録＝1円与信（`member_id` にカードを紐づけ）②毎月の課金＝TBSS側の現行運用を継続。新システムは請求用受注データCSVの出力を担う（P4-12/P5 ＝ Rails版では **R5 or R6**。実装先は 04 R5節「請求用受注データCSV出力の実装先を確定する」で着手時に確定） |
| **D-P9** | **新方式への移行の位置づけ** | **作り直しではなく「URLとパラメータの差し替え」**。現行 `/cgi-bin/get_back.pl`（Shift-JIS・3DS非対応）→ 新 `/ec-payment-front/checkout`（UTF-8・3DS対応） |
| **D-P10** | **会員IDの発行単位**（決定者決定 2026-07-27） | **顧客単位**（1顧客=1会員ID）。商材追加・おまとめ時もカード再登録不要で同一カードから請求可能。`customers.netmove_member_id`（旧 `jasmin_customers.netmove_member_id`）が保持先という現設計と整合（**R2 実装済み**） |
| **D-P11** | **決済失敗（残高不足等）のシステム反映**（決定者決定 2026-07-27） | **手動更新**。TBSSからの報告を受けてスタッフが案件ステータス等を更新（現行踏襲・実装なし）。結果データ取込機能は将来の改善候補に留める |
| **D-P12** | **おまとめ請求の確定タイミング**（決定者決定 2026-07-27） | **2パターン両対応**：①申込時＝購入フォームでおまとめ先（親）案件番号を入力（3択：口振/クレカ/おまとめ。おまとめ選択時はカード登録画面をスキップ）②契約後＝運用スタッフが管理画面から手動設定・変更。**論点1（判定タイミング矛盾）はこれで解消**。Rails版: 保持先カラム（`orders.bundled_billing` / `bundle_target_order_number`）は R2 実装済み。②の管理画面編集は `Admin::OrdersController` の permit に `bundled_billing` / `bundle_target_order_number` が含まれており **R2 で実質実装済み**（親案件番号の存在検証・整合チェックは未実装）。①のフォーム分岐（FormField `payment_method` の値でカード登録ステップをスキップ）は **R5** |

---

## 4. 設計原則（実仕様と一致）

### 4-1. カード情報を自システムに一切通さない（非保持・非通過）

カード番号がメモリ・ログ・DBを一瞬でも通ると PCI DSS の対象範囲に入る。
→ ネットムーブ決済画面で入力（自社フォームにカード欄を置かない）。保存は識別子のみ。

| 保存可 | 保存不可 |
|---|---|
| 取引ID・会員ID・ブランド・下4桁・有効性結果 | カード番号全桁・**CVV（いかなる場合も）**・磁気/ICデータ |

> Rails版補足: Rails の `config.filter_parameters`（`config/initializers/filter_parameter_logging.rb`）に
> `card`, `cvv`, `check_cd`, `hmac` 系キーを追加し、万一のログ混入も伏字化する（ライブラリ層のマスク＝§4-5）。

### 4-2. 二重課金を機構的に防ぐ（冪等性）

タイムアウトで課金成功・応答なしが起きる。素朴な再送は二重課金。
- 冪等キー（`jutyu_cd` 12桁）／送信前にレコード作成／**自動リトライ禁止**／二重送信防止
- > **（Laravel時代の記述）** Horizon デフォルト再試行のまま決済ジョブを流すと**二重課金を自動で起こす**。決済専用キューで再試行無効化（`$tries=1`）。
- > **Rails版（Solid Queue）での実装**（03§2「キュー」／04 R5「決済専用キュー＋自動リトライ無効化」）:
>   1. `config/queue.yml` に **決済専用ワーカー**を追加する: `- queues: payments / threads: 1 / processes: 1 / polling_interval: 1`
>      （既定ワーカーは `queues: "*"` のため、`payments` を **除外した `"-payments"` 指定に変更**するか、
>      優先度付きで専用ワーカーのみが取るように分離する。1スレッド直列化により同一取引の並行処理を機構的に排除）
>   2. 決済系ジョブ（`Payment::ReconciliationJob` 等）は `ApplicationJob` を継承し **`queue_as :payments`**。
>      **`retry_on` を一切付けない**（ActiveJob の既定＝自動再試行なし。Solid Queue も既定で再試行しない）。
>      `discard_on ActiveJob::DeserializationError` のみ許可。**失敗は Solid Queue の failed_executions に残して手動再開**（管理画面 §6 P3-2-f）
>   3. 二重投入防止は Solid Queue の **`limits_concurrency to: 1, key: ->(tx) { tx.jutyu_cd }, duration: 10.minutes`** を併用
>   4. 送信前レコード（`PaymentTransaction.create!` → `jutyu_cd` の **unique index が第一防壁**、ng-05 が最終防壁 = `legacy-research/02` C-g）
>   5. `PaymentTransaction` に `lock_version`（楽観ロック）を持たせ、状態遷移は `with_lock` + 遷移表チェック（§4-4）で二重遷移を拒否

### 4-3. 戻り値を信用しない

リダイレクトの戻りパラメータはブラウザ経由＝改ざん可能。**サーバ間で取引状態を確定**する。
Webhook があれば署名検証＋送信元IP制限。日次で決済会社と突合。

> Rails版: 突合データソースは `Payment::ReconciliationSource` を **抽象クラス（duck type）** として切り、
> 実装＝`Payment::ReconciliationSources::ManualCsv`（管理画面「取引履歴一括ダウンロード」CSVの取込。R-8 の代替策）
> と、将来 Webhook/照会API が提供された場合の `…::Webhook` / `…::InquiryApi` を差し替え可能にする。
> Webhook 受信時の送信元IP制限は `rack-attack`（R0 導入済み）の safelist/blocklist で実装する。

### 4-4. 「不確定」を状態として持つ

```
pending / authorized / captured / failed / unknown / canceled / refunded
```
`unknown`（応答なし・タイムアウト）を **failed に丸めない**（課金済みの可能性→再入力で二重課金）。

> **ネットムーブ側の実状態との対応（2026-07-27 追記）**：管理画面の取引状態は7種
> （`legacy-research/02` §4-7）。対応表を実装で固定する。
>
> | ネットムーブ | 自社 status |
> |---|---|
> | 与信済み | authorized |
> | 売上待ち | authorized（売上化の進行中。自社側は据え置き） |
> | 売上済み | captured |
> | 売上返品待ち / 売上返品済み | refunded（返品待ちは refund 進行中） |
> | 未与信（与信取消済み） | canceled |
> | 未決済（与信が一度も成功していない） | failed |
> | （対応なし＝自社のみ） | pending / unknown |

> **Rails版・状態機械の実装方針（03§2「状態機械＝手実装で忠実移植。AASM等はunknown系の特殊遷移が歪むなら使わない」）**:
> ```ruby
> # app/models/payment_transaction.rb（R5・未実装）
> class PaymentTransaction < ApplicationRecord
>   include Auditable   # 管理者操作（手動再開・突合確定）の差分をAuditLogへ（TRACKED_FIELDS: status card_brand card_last4 …）
>   STATUSES = %w[pending authorized captured failed unknown canceled refunded].freeze
>   NETMOVE_STATE_MAP = { "与信済み" => "authorized", "売上待ち" => "authorized", "売上済み" => "captured",
>                         "売上返品待ち" => "refunded", "売上返品済み" => "refunded",
>                         "未与信" => "canceled", "未決済" => "failed" }.freeze
>   # 遷移表（from => 許可される to）。unknown は failed に丸めない・unknown からは confirm 系でのみ抜ける。
>   TRANSITIONS = {
>     "pending"    => %w[authorized captured failed unknown canceled],
>     "unknown"    => %w[authorized captured failed canceled],   # サーバ間確定/突合（confirm_*）のみ
>     "authorized" => %w[captured canceled refunded unknown],
>     "captured"   => %w[refunded],
>     "failed"     => [], "canceled" => [], "refunded" => []
>   }.freeze
>   # mark_*  : 自社側の観測に基づく暫定遷移（ret_url 受信・タイムアウト検知）。unknown へ落とすのはこちらだけ
>   # confirm_*: サーバ間確定・日次突合・管理画面確認に基づく確定遷移（unknown から抜けられるのはこちらだけ）
>   def mark_unknown!(reason:)      = transition!("unknown",    source: :mark,    reason: reason)
>   def mark_authorized!(payload:)  = transition!("authorized", source: :mark,    payload: payload)
>   def confirm_authorized!(source:) = transition!("authorized", source: :confirm, reconciled_by: source)
>   # …（captured / failed / canceled / refunded も同型）
>   private
>   def transition!(to, source:, **meta)
>     with_lock do   # SELECT … FOR UPDATE + lock_version で二重遷移を拒否
>       raise InvalidTransition, "#{status} -> #{to}" unless TRANSITIONS.fetch(status).include?(to)
>       raise InvalidTransition, "unknown からの離脱は confirm のみ" if status == "unknown" && source == :mark
>       update!(status: to, "#{to}_at": Time.current, last_transition_source: source, **meta.slice(:reason))
>       payment_transaction_logs.create!(kind: "transition", …)   # §4-5
>     end
>   end
> end
> ```
> gem（AASM 等）は採用しない。理由: 「unknown からは confirm 系のみ」「cancel_url 戻りでは遷移させない（§4-9-4）」といった
> **遷移元＝発火源の組み合わせ制約**を宣言的DSLで表すと歪むため。遷移表・mark/confirm 分離・`with_lock` の3点を request/model spec で必ず固定する（§6 P3-2-j）。

### 4-5. 全通信を監査ログに残す

日時・申込ID・冪等キー・エンドポイント・HTTPステータス・所要時間・結果コード。
**カード番号・CVVはマスクして除外**（ライブラリ層で）。`Auditable`/`AuditLog`（旧 `ftlog-port.md` §4。同ファイルは削除済み）の監査基盤に載せる
（※`ftlog-port.md` は削除済み・旧Laravel側に残存。Rails版の監査基盤＝**R0 実装済みの `Auditable` concern / `AuditLog`**）。

> **Rails版の二層構成（2026-08-19）**:
> - **`payment_transaction_logs`（§5-2・R5新設）＝通信ログ**。ret_url / cancel_url の受信はネットムーブからのクロスサイトPOSTで
>   **ログインユーザが存在しない**（`Current.user` = nil）。現行 `audit_logs.user_id` は `null: false` のため **`AuditLog` には載せられない**。
>   よって通信1回1レコードは専用テーブルに書く（`request_id` / `ip_address` は `Current` から、パラメータはマスク後 jsonb）。
> - **`AuditLog`（`Auditable` concern）＝管理者操作の監査**。`PaymentTransaction` を `Auditable` に含め、`TRACKED_FIELDS["PaymentTransaction"]`
>   に `status card_brand card_last4 card_status netmove_member_id` を宣言する。管理画面からの手動再開・突合確定・与信取消は
>   `Current.user` が存在するため通常どおり差分が残る。
> - マスク: `Payment::ParamMasker`（Service）で `check_cd`・電話番号・メール・カード関連キーを伏字化してから jsonb へ保存。
>   `config.filter_parameters` にも同キーを登録（§4-1）。

### 4-6. 決済状態と案件ステータスを分離

`orders.status`（業務。旧 `jasmin_orders.status`）と `payment_transactions.status`（決済）を別テーブル・別ライフサイクルに。
> Rails版: `orders.status` / `contract_status` は R2 実装済み（`OrderStatus` マスタ参照。遷移バリデーションは R6 送り＝04 R6節）。
> 決済状態→業務ステータス連動（P3-2-e）は `Payment::OrderStatusSyncService` として R5 で実装し、
> 「どの決済遷移がどの `orders.status` / `contract_status` に影響するか」の対応表は契約ワークフロー状態機械（P3-4）と同時に確定する。

### 4-7. 3Dセキュア認証項目を送る（2025年10月〜必須・新設）

導入ガイド 5.3：国際ブランドのレギュレーション変更により、**2025年10月以降、
メールアドレス・自宅電話番号・携帯電話番号・職場電話番号のうち、いずれか1つが必須**。
**現在2026年7月＝すでに適用対象**のため、実装必須。

- 最低限 `cardholder_info_email` を送る（申込フォームで取得済みの契約者メールアドレス＝`customers.email`）
- 電話番号を送る場合は**国番号（日本=81）＋先頭0とハイフンを除いた番号**に整形して送る
  （転用元: `customers.sms_mobile_number` / `mobile_phone` / `phone`。整形は `Payment::CardholderInfoBuilder` に集約）
- 請求先住所を送る場合は ISO コード変換が必要
  （国番号 ISO 3166-1 の3桁、都道府県 ISO 3166-2:JP の下2桁。例: 東京都="13"。`customers.prefecture` からの変換表を同 Service に持つ）
- **これらは3Dセキュアの認証率に影響する**（情報が多いほどフリクションレスになりやすい）

> ⚠️ 未指定時の挙動（エラーになるのか、認証率が下がるだけか）は未確認 → 依頼 G-2。

### 4-8. 与信と売上を分けて設計する（新設）

`legacy-research/02` §4-7 のとおり、ネットムーブでは**与信と売上が別ステップ**。
現行運用も1円与信のみで売上は未処理（管理画面「処理日時(売上/返品): -」）。

```
①会員登録（1円与信）  … checkout + member_id → カードがネットムーブ側に紐づく
②毎月の課金（売上処理）… 請求データをネットムーブへ共有（ファイル連携）← 方式判明
```

**②の方式（決定者情報 2026-07-27）**：TBSSが月次で
「ネットムーブから会員データを取得 → 請求データ（会員ID・金額）を作成 →
ネットムーブへ共有（＝今月この人にこの額を請求してと依頼）」する運用。

**スコープ決定（決定者 2026-07-27）：②はシステムのスコープ外。TBSSの現行運用を継続する。**

- 新システムの責務は「**TBSSが突合に使う受注データをCSVエクスポートできること**」のみ。
  請求金額の計算・請求データ作成・結果取り込みは**引き続きTBSS側**（＝P3-2-k は廃止）
- 実装の載せ先：出力定義基盤（`export-profile-design.md`）の1プロファイル
  「**請求用受注データエクスポート**」として定義する。**必要な列は TBSS にヒアリング**
  （最低限：顧客/案件の特定キー・ネットムーブ会員ID・支払方法・プラン/月額・
  おまとめ請求と先案件番号・契約開始/解約/キャンセル日・ステータス）
  > Rails版: R4 実装済みの CSV 基盤（`CsvExport` モデル + `CsvExportJob`。`EXPORT_TARGETS` に対象クラス・列を固定Hashで宣言、
  > `Pundit.policy_scope!` を通した行のみ出力）に **`"BillingOrder"`（請求用受注データ）プロファイルを追加**するのが最短。
  > `export-profile-design.md` の複数プロファイル汎用化（P4-12）は R6 のため、**R5 では `EXPORT_TARGETS` への1エントリ追加で先行実装し、R6 の汎用化時に移す**
  > 判断を 04 R5節「請求用受注データCSV出力の実装先を確定する」で確定すること。
- ⚠️ このため **`netmove_member_id` を新システムに保持していることが前提**
  （P2-4 で実装済み＝Rails版 R2 で `customers.netmove_member_id` 実装済み。既存顧客分の取り込み＝`netmove-card-migration.md` §3 は必要なまま＝R7 ETL）
- ⚠️ **締切がある**：新システム稼働後、**最初の月次請求作業（25日前後）までに**
  このエクスポートが動いていないと請求が止まる。カットオーバー計画（N-1。`release-readiness.md`＝R8）に組み込むこと
- ネットムーブへの A 群質問は縮小（運用が変わらないことの確認1問のみ残す）

### 4-9. ret_url 受け口の実装上の注意（新設・2026-07-27）

ガイド再読で判明した落とし穴（詳細は `legacy-research/02` §5-b）：

1. **セッション非依存で設計する**：ret_url_type=POST は外部からのクロスサイトPOST。
   Laravel 既定（SameSite=Lax）ではセッションCookieが付かず、CSRFトークンも無い。
   → **（Laravel）** ret_url ルートを `VerifyCsrfToken` の except に登録し、**`jutyu_cd` で取引を特定**して
   　 DBから状態を復元する（ログインセッションに依存しない）。
   → **（Rails版）** Rails 既定も `SameSite=Lax` のため同じ問題が起きる。ret_url/cancel_url コントローラで
   　 **`skip_forgery_protection`**（`protect_from_forgery` の除外）、`skip_before_action :authenticate_user!`、
   　 form 配下なら `skip_before_action :require_form_sales_representative!` を明示し、`params[:jutyu_cd]` で
   　 `PaymentTransaction` を引く。**セッション・Cookie を一切参照しない**（request spec で「Cookie無しPOSTで動く」ことを固定）。
   　 コントローラの配置は §4-10。
2. **check_cd 検証には金額が要る**：検証用 check_cd は「受注コード,ブランド,金額」から生成
   されるが、**戻りに金額パラメータは無い**。送信前レコード（§4-2）の `amount` をDBから引く。
3. **成功判定は「member_id 非ブランク ∧ check_cd 一致」**：ret_url に結果コードが無いため。
   どちらか欠けたら captured/authorized にせず **unknown 留置**。
4. **cancel_url は署名なし**（check_cd ブランク）：キャンセル戻りを根拠に状態遷移しない。
5. **expiration_date は明示指定**する（未指定は翌日失効）。失効時は新規採番で再開。

> **Rails版・HMAC の実装（§4-9-2/3 と `legacy-research/02` §4-1）**：
> ```ruby
> # app/services/payment/check_code.rb（R5・未実装）
> module Payment
>   class CheckCode
>     PREFIX = "HM"
>     def initialize(site_code:) = @key = Base64.decode64(Payment::Config.hmac_key_for(site_code))  # 鍵は credentials/ENV。値は文書に書かない
>     # 送信時: "jutyu_cd,sum_price"
>     def for_checkout(jutyu_cd:, sum_price:) = digest("#{jutyu_cd},#{sum_price}")
>     # ret_url 検証時: "jutyu_cd,user_card_corp,sum_price"（生成データが異なるため別メソッド）
>     def for_return(jutyu_cd:, card_brand:, sum_price:) = digest("#{jutyu_cd},#{card_brand},#{sum_price}")
>     def valid_return?(given:, **args) = ActiveSupport::SecurityUtils.secure_compare(given.to_s, for_return(**args))
>     private
>     def digest(message) = PREFIX + OpenSSL::HMAC.hexdigest("SHA256", @key, message)  # 16進小文字
>   end
> end
> ```
> 比較は必ず `ActiveSupport::SecurityUtils.secure_compare`（タイミング攻撃対策）。鍵は `Rails.application.credentials.netmove[<site_code>][:hmac_key]`
> または ENV から `Payment::Config` 経由でのみ取得し、**サイトコード単位で複数保持できる Hash 構造**にする（R-11・論点10）。

### 4-10. Rails版のアプリ構造・配置（2026-08-19 新設）

03§3 の section 設計（admin / form / mypage ＝ **認証系統の仕切り**。`SystemPermissionSyncService#section_for` がコントローラの
ネームスペースから自動判定し、`form/` は `authorize_system_permission!` を完全スキップ（03§8-2 決定b）、それ以外は既定で `admin` 扱い＝フェイルクローズ）
に整合させ、決済系コントローラを次のように配置することを提案する。

| 機能 | 配置（提案） | section | 認証・認可 | 備考 |
|---|---|---|---|---|
| 決済開始（checkout パラメータ生成・遷移） | `Form::PaymentsController#new/#create`（`form/applications/:token/payment`） | form | `FormAuthenticatable`（営業担当者セッション） | R3 の `Form::ApplicationsController#submit` 直後（Order 作成後）に差し込む。`Payment::CheckoutSession` Service が `PaymentTransaction` を **先に作成**し（§4-2）、check_cd 付きの自動送信フォーム（ERB + Stimulus）を描画 |
| **ret_url / cancel_url 受け口** | **`Form::PaymentReturnsController#create`（ret_url）/ `#cancel`（cancel_url）**（`form/payments/return`, `form/payments/cancel`） | **form** | **`skip_forgery_protection` + `skip_before_action :authenticate_user!, :require_form_sales_representative!`**。セッション不参照（§4-9-1） | **推奨案**。理由: (1) 申込フローの続き（同じ顧客の画面遷移）で form section の「営業担当者/顧客の系統」に属する (2) `form/` は RBAC スキップ済みで `SystemPermissionSyncService` / `ApplicationController#skip_system_permission_authorization?` を**変更せずに済む** (3) 認証を外す範囲がこの1コントローラに閉じる。`Form::BaseController` は継承せず `ApplicationController` 直下＋ `form/` パスに置く。**rack-attack で ret_url へのレート制限**を掛ける |
| （代替案）`Webhooks::NetmoveController` | 新規 `webhooks/` 名前空間 | （なし） | `EXCLUDED_CONTROLLER_PREFIXES` に `webhooks/` を追加 **かつ** `skip_system_permission_authorization?` に `webhooks/` を追加 | 将来 Webhook（依頼 C-3）が提供された場合の置き場。現状は **RBAC 基盤2箇所の改修が必要**なため、ret_url だけのために新設しない。Webhook 提供時に本案へ移す判断を再検討する（**要確認**） |
| 決済状況の確認・手動再開・突合確定 UI（P3-2-f） | `Admin::PaymentTransactionsController`（index/show + member `reopen`/`confirm`）、`Admin::PaymentReconciliationsController`（CSV取込） | admin | RBAC（`SystemPermission` 自動カタログ）＋ **Pundit `PaymentTransactionPolicy`（`policy_scope` = 親 Order の代理店スコープを継承）** | 04 R3レビュー指摘「`OrderWorkDetail` 用 Policy が無い」と同じ轍を踏まないよう Policy を同時に新設 |
| カード変更導線（`option=member-modify`） | 候補A: `Mypage::CardsController`（顧客本人が再 checkout）／候補B: 管理画面からメールリンク決済案内 | mypage / admin | Devise Customer + OTP／RBAC | **未決**（`netmove-card-migration.md` §3「共通」・S-7 現行手順未確認）。R5 スコープ境界として明記のみ |
| Service Object 群 | `app/services/payment/`: `Config` `CheckCode` `JutyuCodeGenerator`（`SequenceCounter` 利用）`MemberIdAllocator`（新規採番/既存引継ぎ両対応）`CardholderInfoBuilder` `CheckoutSession` `ReturnHandler` `ParamMasker` `OrderStatusSyncService` `ReconciliationSource` + `reconciliation_sources/*` | — | — | 03§6「services（ビジネスロジック集約）」。コントローラは薄く保つ |
| ジョブ | `app/jobs/payment/reconciliation_job.rb`（日次突合。`queue_as :payments`、`retry_on` なし）、`payment/expire_stale_transactions_job.rb`（`expires_at` 超過の pending を unknown/failed でなく **expired 扱いに**するかは要設計。Solid Queue recurring で日次） | — | — | §4-2 |
| メール | `PaymentMailer`（決済失敗/不確定の社内通知。宛先ルール E6 は未決＝04 R4節） | — | `deliver_later`（既定キューでよい。決済専用キューは課金に関わる処理のみ） | |

---

## 5. データ設計（暫定）

> Rails版: いずれも **未実装（R5）**。UUID主キー（`id: :uuid, default: gen_random_uuid()`）・`created_by_id`/`updated_by_id`（`TracksUser`）・
> annotaterb 注釈・PostgreSQL 前提（旧 MySQL DDL の `string(...,12)` は `t.string :jutyu_cd, limit: 12` に読み替え）。

### 5-1. `payment_transactions`

| カラム | 内容 |
|---|---|
| `id` | UUID |
| `order_id` | 対象案件（旧 `jasmin_order_id`。※商材増・おまとめ請求で N案件:1決済 が必要になる可能性 → §8 論点9＝04 Q-36）。「登録契機の案件」として保持 |
| `customer_id` | **追加（論点9の帰結）**：会員IDは顧客単位（D-P10）のため顧客への FK を持つ。`customers.netmove_member_id` と整合させる |
| `jutyu_cd` | 受注コード（**桁数未確定**＝04 Q-37・冪等キー・**unique index**）。ガイド本文は「12桁」だが構成は4+7=11桁。実データは `S084-6001864`（ハイフン込み12文字）→ `legacy-research/02` §4-3・依頼 D-1。**確定まで12文字前提**（`t.string :jutyu_cd, limit: 12, null: false` + unique index）。下位7桁は `SequenceCounter.next_value!("netmove_jutyu_cd_<site_code>")` で採番し**会員IDから独立**させる（`netmove-card-migration.md` §6-3） |
| `site_code` | **追加**：サイトコード（`S084`）。R-11/論点10（複数サイト構造）に備える |
| `netmove_member_id` | **追加**：checkout に送った会員ID（送信時点のスナップショット。正は `customers.netmove_member_id`） |
| `provider` | `netmove` |
| `provider_transaction_id` | 外部取引ID（ret_url には返らないため突合時に埋まる想定。伝票番号/承認番号相当） |
| `status` | §4-4（`STATUSES` inclusion + 遷移表） |
| `last_transition_source` | **追加**：`mark` / `confirm`（§4-4 の分離を記録） |
| `amount` / `currency` | 金額（整数）/ JPY（会員登録＝1円） |
| `card_brand`（`user_card_corp`）/ `card_last4` | 表示用 |
| `card_status` | verified 等 |
| `expires_at` | **追加**：checkout に送った `expiration_date`（§4-9-5） |
| `authorized_at` / `captured_at` / `failed_at` / `canceled_at` / `refunded_at` / `unknown_at` | 各状態時刻 |
| `failure_code` / `failure_message` | 失敗理由（ok-01 / ng-02〜19。管理画面確認値を突合で転記） |
| `raw_response` | マスク後の応答（jsonb） |
| `lock_version` | **追加**：楽観ロック（§4-2-5） |
| `created_by_id` / `updated_by_id` / timestamps | `TracksUser` |

インデックス: `jutyu_cd` unique、`order_id`、`customer_id`、`status`、`(status, created_at)`（unknown 滞留の監視用）。

### 5-2. `payment_transaction_logs`

送受信1回1レコード（§4-5）。保存期間は監査ログと同方針（5年。Q-22）。

| カラム | 内容 |
|---|---|
| `id` / `payment_transaction_id` | UUID / FK |
| `kind` | `checkout_request` / `ret_url` / `cancel_url` / `reconcile` / `transition` / `webhook` |
| `direction` | `outbound` / `inbound` |
| `endpoint` / `http_status` / `duration_ms` / `result_code` | 通信情報 |
| `request_params` / `response_params` | **マスク後** jsonb（`Payment::ParamMasker`） |
| `request_id` / `ip_address` | `Current.request_id` / `Current.ip_address`（ログインユーザは無くてもよい） |
| `created_at` | 追記型（UPDATE しない） |

---

## 6. 実装タスク（P3-1 / P3-2 ＝ Rails版 R5）

| # | 内容 | Rails版の状態（2026-08-19） |
|---|---|---|
| P3-1-a | API仕様の受領・読み合わせ ✅（ネットムーブ導入ガイド） | ✅ |
| P3-1-b | 連携方式の確定 ✅（リダイレクト型） | ✅ |
| P3-1-c | シーケンス図（正常・失敗・タイムアウト・戻り改ざん） | 未（R5 設計） |
| P3-1-d | 状態遷移図（§4-4） | 未（R5 設計。遷移表は §4-4 のコード案が叩き台） |
| P3-1-e | データ設計の確定（§5） | 未（R5。migration 化） |
| P3-1-f | エラーコード対応表 ✅（導入ガイド §5.2 取得済み。`legacy-research/02` §4-6。ok-01 / ng-02〜19。**推奨ハンドリングのみ未確認**＝依頼 E-3） | ✅ |
| **P3-1-g** | **3Dセキュア認証項目の実装設計**（§4-7。メール・電話番号の整形／ISOコード変換）**新規** | 未（R5。`Payment::CardholderInfoBuilder`） |
| **P3-1-h** | **継続課金（売上処理）の方式確定**（§4-8・I-17）。依頼 A 群の回答および社内 S-1 の確認結果を受けて設計 **新規・クリティカル** | 方式判明（ファイル連携・スコープ外）。残＝請求用CSV列定義（論点14） |
| P3-2-a | APIクライアント（checkout POST・HMAC・タイムアウト・冪等キー） | 未（R5。`Payment::CheckCode` / `CheckoutSession` / `JutyuCodeGenerator`） |
| P3-2-b | 決済開始（申込フローから checkout へ） | 未（R5。`Form::PaymentsController`。R3 の submit 直後に差し込む） |
| P3-2-c | 戻り受け口（ret_url）＋サーバ間確定 | 未（R5。`Form::PaymentReturnsController` + `Payment::ReturnHandler`。§4-9/§4-10） |
| P3-2-d | Webhook 受信＋署名検証（提供される場合） | 未（提供未定。§4-10 代替案） |
| P3-2-e | 決済状態→業務ステータス連動（§4-6） | 未（R5。`Payment::OrderStatusSyncService`。P3-4 と同時設計） |
| P3-2-f | 失敗・不確定時の管理画面での確認／再開 UI | 未（R5。`Admin::PaymentTransactionsController` + Policy） |
| P3-2-g | 日次突合バッチ | 未（R5。`Payment::ReconciliationJob` + `ReconciliationSources::ManualCsv`） |
| P3-2-h | 決済専用キュー＋自動リトライ無効化 | 未（R5。`config/queue.yml` の `payments` ワーカー + `queue_as :payments` + `retry_on` 禁止。§4-2） |
| P3-2-i | 実結線確認（**検証専用環境は無い模様**。開通処理＋商用カードで実施＝依頼 E-1〜E-4） | 未（04 Q-39 ステージング検証方式の確定が前提） |
| P3-2-j | **テストコード**（正常・失敗・タイムアウト・二重送信・改ざん戻り） | 未（R5。RSpec: model spec＝遷移表・mark/confirm、request spec＝ret_url Cookie無しPOST・check_cd不一致・member_id空・二重POST、job spec＝retry無し。04 R5「request spec 必須」） |
| **P3-2-k** | **廃止**：継続課金（毎月の売上処理）はTBSS側の現行運用を継続。新システム側はP4-12/P5で請求用受注データCSV出力を扱う | 廃止のまま。CSV出力＝R5 or R6（§4-8） |
| **P3-2-l** | 3Dセキュア認証項目の送信実装（§4-7） | 未（R5） |
| **P3-2-m** | 新方式への移行作業（D-P9）。既存会員IDの引き継ぎ可否により作業量が激変（I-20／依頼 B-3） | 未（R5 + R7 ETL。`netmove-card-migration.md`） |

> P3-2-j は省略しない。タイムアウト・二重送信・改ざんは手動再現不可。モック自動テストが唯一の手段。
> Rails版: 外部HTTPは WebMock 等でスタブし、`Payment::CheckCode` は実鍵を使わずテスト用ダミー鍵で検証する。

---

## 7. リスク

| # | リスク | 対策 |
|---|---|---|
| R-1 | ~~API仕様の受領遅延~~ | ✅ 解消（受領・全文読了済み） |
| R-2 | 二重課金 | §4-2 |
| R-3 | 戻りURL改ざんによる不正契約 | §4-3。**ただし確定手段が未提供（R-8）** |
| R-4 | ~~カード情報が自システムを通過し PCI DSS 対象化~~ | ✅ **元から非該当**。現行方式でもカード入力はネットムーブ側ページ（`legacy-research/02` §0） |
| R-5 | 決済会社側の障害 | 縮退運用（Q-27） |
| R-6 | ~~テスト環境が提供されない~~ | **提供されない前提で確定的**（ガイド6.1）。モック中心＋商用カードでの実結線に切り替え。損害の出ない金額（1円与信）で実施し、与信取消で後始末（依頼 E-4） |
| **R-7** | **継続課金（売上処理）の手段が未確定のまま実装が進み、毎月の課金が実装されない** | §4-8・P3-1-h。**依頼 A 群を最優先。社内 S-1（NM会員IDエクセル／カード非保持化システムの実物確認）で先行判明する可能性** |
| **R-8** | **決済成否の確定手段が無く、`unknown` が滞留する** | 依頼 C-1〜C-4。代替＝管理画面「取引履歴一括ダウンロード」による日次突合。`ReconciliationSource` interface で抽象化済み（Rails版: `Payment::ReconciliationSource` duck type） |
| **R-9** | **移行時に既存会員IDのカード情報が引き継げず、既存顧客の再登録が必要になる** | **深掘り済み → `netmove-card-migration.md`**。影響＝課金中クレカ顧客 約400件（BridgePlus。Bridge側は未集計）。状況証拠は「引き継がれる」寄り（同一ホスト・同一サイトS084・管理画面共通・会員IDは加盟店発行）だが公式確認が無い → 依頼 B-3a〜e。**対応表（顧客⇔NM会員ID）が「最新NM会員IDエクセル」にしか無い疑い**があり、引き継がれても取り込み・検証が必要（社内 S-1/S-6）。最悪時の再登録手段は「メールリンク決済」が候補 |
| **R-10** | 3Dセキュア必須項目（2025-10〜）の未対応で認証失敗・決済不成立が多発 | §4-7・P3-2-l。最低限メールアドレスを送る実装を初回から入れる |
| **R-11** | 商材追加時にサイト分割が必要と判明し、単一サイトコード前提の実装が全面改修になる | **設定を「サイト単位で複数持てる」構造で実装**（サイトコード・HMACキーを配列で保持。Rails版: `Payment::Config` が credentials/ENV の Hash をサイトコードで引く。`payment_transactions.site_code`）。実装が途中の今なら低コスト。依頼 F-1/F-2 |
| **R-12（Rails版追加）** | ret_url 受け口を `authenticate_user!`/CSRF/RBAC から外すことで攻撃面が増える | 受け口は `jutyu_cd` + `check_cd`（HMAC）検証・rack-attack レート制限・状態遷移は遷移表で制限（cancel_url では遷移しない）。認証スキップは1コントローラに閉じ、request spec で「Cookie無し・改ざん check_cd・存在しない jutyu_cd」を固定 |

---

## 8. 未決定事項（`../development-plan.md` §8 ＝ 04「R5着手前チェックリスト」）

> 2026-08-19: 04-rails-implementation-plan.md の R5着手前チェックリスト（Q-25〜27・Q-35〜39）との対応を付記。**いずれも未解決のまま**（消していない）。

| # | 論点 | 04 対応 |
|---|---|---|
| Q-7 | 支払方法の種類（クレカのみ / 口座振替等） | D-P2 で暫定（クレカ＋口振）。信販は Q-26 |
| Q-24 | 課金モデル → ✅ 継続課金で確定的 | — |
| Q-25 | 返金・キャンセルの業務要件 | **04 Q-25**（`release-readiness.md` D-3）。状態機械の `refunded` / `canceled` 遷移と管理画面「与信取消」操作の要否に直結 |
| Q-26 | 信販（アシスト信販）を本フローに含めるか | **04 Q-26**。`orders.finance_*` 9カラムは R2 実装済み（記録用）。フロー化する場合は決済ステップの分岐が増える |
| Q-27 | 決済障害時の縮退運用の要否 | **04 Q-27**。ng-19（同時実行数オーバー）・ネットムーブ障害時に「カード登録を後回しにして申込を通すか」 |
| P-N1〜8 | ネットムーブへの確認事項（`legacy-research/02` §6）。依頼書＝`../drafts/netmove-request-draft.md`（A〜J の34項目。※旧Laravel側 `requirements/drafts/`。brige-crm には未コピー） | — |
| ~~論点9~~ | ✅ **ほぼ解消（2026-07-27）**：毎月の請求（N案件の合算含む）は**TBSS側のスコープ**となったため、`payment_transactions` は「カード登録（与信）イベント」の記録に純化される。会員IDは顧客単位（D-P10）のため、**`customer_id` を持たせる**のが自然（初回申込の案件経由で登録するため `order_id` は「登録契機の案件」として残してよい）。中間「請求」テーブルは不要 | **04 Q-36**（決済トランザクションの紐づけ単位）。本書の結論＝`customer_id` + `order_id` 併記（§5-1）。04 側で「確定」として閉じてよいか 決定者 確認 |
| **論点10** | **商材ごとのサイト分割**（依頼 F-1/F-2）。分ける場合、サイトコード・HMACキー・決済画面設定・カード明細表記が商材単位になる。実装は複数サイト設定を持てる構造にしておく（R-11） | 04 未記載。R5 設計上は `site_code` 列 + `Payment::Config` Hash で吸収済み（着手前確定は不要） |
| **論点14** | **請求用受注データエクスポートの列定義**（§4-8）。TBSSへのヒアリングで確定（S-1）。**新システム稼働後、最初の月次請求（25日前後）までに必須**＝カットオーバー計画（N-1）に締切として組み込む | 04 R5「請求用受注データCSV出力の実装先を確定する」・R8（release-readiness） |
| I-19 / D-1 | 受注コードの桁数（11 or 12）・採番規則 | **04 Q-37** |
| I-18 / C-1〜C-4 / R-8 | 決済結果の確定手段（ret_url に結果コード無し） | **04 Q-38** |
| R-6 / P3-2-i / E-1〜E-4 | ステージング（実結線）検証方式。検証環境無し・商用カード・1円与信＋与信取消 | **04 Q-39** |
| （Rails版追加）§4-10 | ret_url 受け口を form section に置く案の妥当性（vs `webhooks/` 名前空間新設）／カード変更導線の section（mypage or admin） | 04 未記載。CTO 判断で足りる見込みだが R5 着手時に確定 |

---

## 9. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版作成。API仕様に依存しない設計原則（§4）を定義 |
| 2026-07-24 | ネットムーブAPI仕様の受領を反映（W-1解消）。連携方式・課金モデル・対応ブランドを確定。`legacy-research/02` と連動 |
| 2026-07-27 | **導入ガイド全23ページ読了＋現行キャプチャ精査を反映**。①旧方式の誤認を訂正（現行もネットムーブ側ページ／移行＝URL・パラメータ差し替え＝D-P9）②与信と売上の分離を明文化（D-P8・§4-8）③3Dセキュア必須項目を新設（§4-7）④I-17〜I-21 を追加⑤R-4/R-6 を解消・R-7〜R-11 を新設⑥P3-1-g/h・P3-2-k/l/m を追加⑦受注コード桁数の未確定を明記⑧論点9（紐づけ単位）・論点10（サイト分割）を追加 |
| 2026-07-27 (2回目) | **再読・B-3深掘りを反映**。①§4-4 にネットムーブ7状態との対応表 ②§4-9（ret_url 受け口の実装注意：セッション非依存・金額のDB参照・成功判定・cancel_url無署名・失効）を新設 ③R-9 を `netmove-card-migration.md` に接続（影響約400件・対応表Excel疑い） |
| 2026-08-19 | **Rails版改訂（brige-crm / R5）**。①Laravel固有記述（Horizon・`$tries`・`VerifyCsrfToken`・`jasmin_*` モデル/テーブル名）を Solid Queue 決済専用キュー・`retry_on` 禁止・`skip_forgery_protection`・`Order`/`Customer` へ読み替え ②§4-4 に `PaymentTransaction` 手実装状態機械（遷移表・mark/confirm 分離・`with_lock`）のコード案 ③§4-5 を `payment_transaction_logs`（通信ログ）＋`Auditable`/`AuditLog`（管理者操作）の二層に整理（`audit_logs.user_id NOT NULL` のため）④§4-9 に `OpenSSL::HMAC` + `secure_compare` の `Payment::CheckCode` 案 ⑤§4-10（Rails版のコントローラ配置＝ret_url は form section 推奨・Service Object 群・ジョブ）を新設 ⑥§2-3/§5 に現行実装との突合（実装済み／未実装 R5）を明記、`customer_id`/`site_code`/`expires_at`/`lock_version` 等を追加 ⑦§6 に Rails版の状態列 ⑧§8 に 04 Q-25〜27/Q-35〜39 との対応を付記 ⑨R-12 追加 |
