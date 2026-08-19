# 契約確認文書 設計メモ — 重要事項説明チェック・申込確認メール/確認書（旧 P3-12 / P3-13）

> **Rails版改訂: 2026-08-19。** 旧Laravelプロジェクト（`boilerplate-vue-env/laravel/requirements/design/p3-12-13-confirmation-docs.md`）を
> brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて見直し。**フェーズ対応: R5（契約フロー・決済。P3-12 重説チェック／P3-13 申込確認メール・確認書）**。
> 突合日 2026-08-19 時点: **重説チェック（`disclosure_*`）・案件文書（`order_documents`）・確認書PDF・申込確認メールはいずれも未実装（R5）**。
> 隣接する既存実装＝申込セッション `applications`（R3。`customer_id` / `order_id` / `completed_at` あり）、通知基盤（R4。`notifications` + Active Storage 添付・
> `notification_templates`・`RecipientResolver`・`InquiryMessageMailJob` 等）、監査ログ（R0 `Auditable` / `AuditLog`）、同意系カラム（R2 `orders.elderly_consent` 等）。
> Laravel固有記述（`jasmin_orders`・spatie/activitylog・`file_path`・`notification_attachments`・enum）は Rails 版へ読み替え、
> 業務定義・境界整理・未決論点 Q-1〜9 は原文のまま保持。**Q-1〜9 は 04 R5着手前チェックリストの Q-35 に対応**（§5 に付記）。

> **ステータス: ドラフト（設計メモ。実装計画化は別途＝04 R5 節）**
>
> 作成日: 2026-07-26 ／ Rails版改訂: 2026-08-19
> 発端: `../development-plan-review-20260726.md` §3-1 の G1/G2（basic-design §6 に明記されているのに
> 計画タスクに番号が無かった2機能。※同レビューは旧Laravel側に残存）。計画書には P3-12 / P3-13 として追加済み（`../development-plan.md` §3 P3
> ＝ Rails版 `04-rails-implementation-plan.md` R5「入力チェック設定・キーワード自動選定・重説チェック・申込確認メール」）。
> 本書はその設計の叩き台。**未確定事項が多く、実装着手前に §5 の論点解消が必要。**
>
> 根拠資料:
> - `basic-design.md` §6（申込登録・想定フロー・確認中事項④）、§9（不備チェック）、§12（確認コール）、§13〜14（契約書）
> - `business-flow-analysis.md` §1-2（9工程）、§7-1（日付の定義）
> - `legacy-research/06-bw-operations.md`（BW業務。※重説・確認書の手順は登場しない → §2 参照）
> - `payment-integration.md` §2-2（申込フロー内での位置づけ）
> - `notification-matrix.md` E2/E5（申込確認・契約確認メールの宛先）
> - `release-readiness.md` G-3 / M-5〜M-7（重説・申込書の現行文面/サンプルの入手状況）

---

## 1. 各機能の定義と隣接工程との境界

basic-design §6-1 の想定フロー（本書の対象に ★ を付す）:

```
営業担当者ログイン                   … R3 実装済み（Form::SessionsController + メールOTP）
  → 商品選択                         … R3 実装済み（Form::ApplicationsController#new/create）
  → 顧客側が顧客情報を入力           … R3 実装済み（steps/:n → #submit で Customer/Store/Order 作成）
  → クレカ登録                       … P3-2（決済連携）＝ R5（payment-integration.md）
  → 申込確認メール（確認書添付）     … ★ P3-13 ＝ R5
  → 重要事項説明チェック             … ★ P3-12 ＝ R5
  → 契約確認メール（契約書添付）     … P3-8/9（契約書生成・送付）＝ R5
```

### 1-1. P3-12: 重要事項説明チェックの実施・記録

**定義**: 申込時に、契約の重要事項（利用規約・契約期間・違約金等 ※項目は未確定 → §5 Q-1）が
顧客に説明・確認されたことをチェックし、**「誰が・いつ・どの項目を・どう確認したか」を記録として残す**機能。

**隣接工程との違い（1段落）**:
P3-5 不備チェック（basic-design §9）は「**管理者が**、代理店/顧客の入力した**契約情報の内容**に不備が
ないかを事後確認する」社内品質工程であり、P3-7 確認コール（同 §12）は「**管理者が顧客に架電して**
申込意思・内容を確認する」社内→顧客の事後確認工程である。これに対し P3-12 重要事項説明チェックは、
**申込フローの中（申込確認メールの後・契約確認メールの前）で、顧客に対する説明義務の履行を記録する**
工程であり、確認する主体（想定は顧客本人 or 営業担当者。未確定 → §5 Q-2）・確認する対象
（入力内容の正誤ではなく**説明事項への同意/理解**）・目的（品質管理ではなく**コンプライアンス証跡**）の
3点すべてが異なる。不備チェックや確認コールに「重説も済んだことにする」形で吸収してはならない
（レビュー G1 の指摘どおり別工程として実装する）。

### 1-2. P3-13: 申込確認メール・確認書の生成/送付

**定義**: 申込完了（クレカ登録まで完了）時点で、顧客宛に**申込内容の控えとなる「確認書」を生成し、
申込確認メールに添付して送付**する機能。生成した確認書の版数と送付記録を残す。

**隣接工程との違い（1段落）**:
P3-8/9 の「契約書」は**契約確定済み**（確認コール完了後）の契約情報から生成される文書であり
（basic-design §13「契約確定済みの契約情報を対象として契約書データを生成する」）、送付は
フロー末尾の「契約確認メール（契約書添付）」で行われる。一方 P3-13 の「確認書」は**契約確定前・
申込直後**に送る申込内容の控えであり、対象データ（申込時点のスナップショット vs 確定契約情報）・
送付タイミング（申込直後 vs 契約確定後）・文書の性質（受付確認 vs 契約文書）が異なる。
basic-design §6 のフローで「申込確認メール（確認書添付）」と「契約確認メール（契約書添付）」が
別ステップとして併記されていることが、両者が別文書である根拠（レビュー G2）。
ただし確認書と契約書で**生成基盤（PDF生成・版数管理）は共通化できる**見込み（→ §4）。

---

## 2. 現行運用での実態（資料から取れる範囲）

**結論: どちらも現行資料からの根拠が薄い。実装前に要ヒアリング。**

| 観点 | 資料から取れること | 取れないこと |
|---|---|---|
| 重説チェックの現行運用 | `business-flow-analysis.md` §1-2 の9工程①は「電子契約申込フォームから入力・電子署名・（クレカ登録）」。**独立した重説チェック工程は9工程に登場しない**。`release-readiness.md` M-7 で「利用規約・重要事項・特商法の現行文面」は法務からの入手が「未」 | 現行フォームで重説がどう扱われているか（電子署名に包含？チェックボックス？口頭のみ？）→ **要ヒアリング** |
| 重説の項目内容 | `release-readiness.md` G-3「利用規約・重要事項説明の内容確定」がリリース前提条件として未了 | 重説の必須項目リストそのもの → **要ヒアリング（法務・業務）** |
| 確認書の現行運用 | `business-flow-analysis.md` §1-2 ④・§7-1 に「確認コール後に契約日を入力した**申込書**を送付」とあり、`release-readiness.md` M-5/M-6 に「申込書控えPDFあり」 | 現行の「申込書（控え）」が basic-design の「確認書」（申込直後送付）と「契約書」（確定後送付）のどちらに対応するか。**現行は確認コール後の送付であり、basic-design の「申込直後に確認書」とはタイミングが一致しない** → **要ヒアリング** |
| BW業務での扱い | `legacy-research/06-bw-operations.md` に重説・確認書の手順は**登場しない**（解約・掲示板・GBP権限等が中心） | — |
| メール宛先 | `notification-matrix.md` E2: 顧客宛○（フローからの判断）。管理者/バックヤード/代理店/営業への Cc は全て「?（要確認）」 | Cc 要否 → **要ヒアリング（Q-21 と併せて）** |

> ⚠️ 特に確認書は「現行に存在する申込書控えの前倒し送付」なのか「新設文書」なのかで
> テンプレの作り方が変わる。捏造せず、§5 Q-5 の確認を先に行うこと。

---

## 3. データモデル案

> 案であり確定ではない。テーブル名・持ち方は実装計画化の際に P3-8（契約書版数管理）の設計と併せて確定する。

### 3-1. P3-12: 重説チェックの記録

「誰が・いつ・どの項目を・結果」を第一級の記録として持つ。2テーブル＋項目マスタの3点構成を提案する。
（Rails版: いずれも **未実装（R5）**。UUID主キー・`created_by_id`/`updated_by_id`（`TracksUser`）・annotaterb 注釈・PostgreSQL 前提。
モデル名 `DisclosureItemSet` / `DisclosureItem` / `DisclosureCheck` / `DisclosureCheckItem`）

```
disclosure_item_sets（重説項目セット＝版管理されたマスタ）
  id / version / effective_from / created_by_id / timestamps
disclosure_items（項目マスタ。セットに属する）
  id / disclosure_item_set_id / sort_order / title / body / is_required / timestamps

disclosure_checks（実施記録ヘッダ）
  id / order_id（FK。旧 jasmin_order_id。application_id も併記候補 → 論点 Q-3）
  disclosure_item_set_id（どの版の項目セットで実施したか）
  performed_at（いつ）
  performed_by_type / performed_by_id（誰が: ポリモーフィック belongs_to :performed_by, polymorphic: true。
    Customer（顧客本人）/ SalesRepresentative / User → Q-2 の決定に依存）
  method（web_check / oral_then_recorded 等 → Q-2 の決定に依存。string + inclusion validation。enum は使わずマスタ/定数で）
  result（completed / incomplete）
  timestamps

disclosure_check_items（項目ごとの結果明細）
  id / disclosure_check_id / disclosure_item_id / checked（bool）/ checked_at
```

Rails版の置き場（案）: 実施UIは Q-2 の決定で変わる。顧客本人が Web でチェックする場合＝**form section**（`Form::DisclosureChecksController`。
申込フロー `form/applications/:token/...` の続き。営業担当者セッションのまま顧客が画面操作する現行R3方式）、または **mypage section**
（`Mypage::DisclosureChecksController`。Customer ログイン後）。営業担当者が口頭説明後に記録する場合＝form section。
管理者の閲覧＝**admin section**（`Admin::Orders#show` 内の実施記録一覧 + `Admin::DisclosureItemSetsController` で項目セットの版管理。
RBAC 自動カタログ + Pundit `policy_scope` は親 Order の代理店スコープを継承）。

**設計意図**:
- 重説項目は将来変更されるため、**項目セットを版管理**し、実施記録は「どの版で説明したか」を固定参照する
  （後から項目が変わっても過去の証跡が壊れない）。
- コンプライアンス証跡なので **UPDATE で上書きせず追記型**（再実施は新しい `disclosure_checks` 行）。

**既存テーブルとの関係**:
- `orders`（旧 `jasmin_orders`。R2 実装済み）: `disclosure_checks.order_id` で紐づけ。案件詳細から実施記録を参照可能にする。
  ステータス遷移条件に使うかは P3-4 と要調整（→ §4）。
- `AuditLog`（R0 実装済み。旧 spatie/laravel-activitylog 相当＝ftlog `Auditable` concern）: 汎用の操作履歴であり、**法的証跡の代替にしない**。
  `DisclosureCheck` に `Auditable` を include し `TRACKED_FIELDS` を宣言すれば作成操作が `AuditLog` にも残るのは通常どおり（二重目的にしない）。
  なお `audit_logs.user_id` は `null: false` のため、顧客本人（`Current.user` が nil の form 経由）による実施は AuditLog に載らない可能性がある
  → **法的証跡は `disclosure_checks` 側で完結**させる設計を維持する根拠がここにもある。
- 参考: `orders` には既に `elderly_consent` / `elderly_consent_collected_at` / `consent_status` / `consent_rep_age` /
  `consent_contact_age` 等の同意系カラムがある（現行踏襲の単カラム方式。**R2 実装済み**）。重説を同様の単カラムにしない理由は、
  「どの項目を・どの版で」の粒度が必要なため。

### 3-2. P3-13: 確認書の版数・送付記録

**文書の版数管理は P3-8 の契約書版数管理と共通の器を使う**ことを提案する（basic-design §13
「作成版数または最新版を管理可能とする」は契約書側の要件だが、確認書にも同じ機構が要る）。
（Rails版: **未実装（R5）**。モデル名 `OrderDocument` / `OrderDocumentDelivery`）

```
order_documents（案件文書。契約書 P3-8 と共用）
  id / order_id（旧 jasmin_order_id）/ document_type（confirmation = 確認書 / contract = 契約書）
  version / generated_at / generated_by_id / source_snapshot（生成時の申込内容 jsonb → 論点 Q-6）
  timestamps
  ※ ファイル本体は file_path 列ではなく Active Storage（has_one_attached :file）で保持
    （R4 の InquiryMessage / Notification 添付と同じ機構。本番のストレージサービスは R8 で確定）
  ※ (order_id, document_type, version) に unique index

order_document_deliveries（送付記録）
  id / order_document_id / channel（email）/ recipient_email / sent_at / status（sent / failed）
  / notification_ref（送信基盤側のレコードへの参照 → 下記。Rails版: ActionMailer の Message-ID を保存する `message_id` 列、
    または R4 `Notification` を流用する場合は `notification_id` FK。Q-7 の決定に依存）
```

**PDF 生成基盤（03§2「PDF（契約書）: 要選定（grover / ferrum系 or prawn）— P3相当フェーズ＝R5 で決定」）**:

| 候補 | 概要 | 長所 | 短所 |
|---|---|---|---|
| grover / ferrum（headless Chrome で HTML→PDF） | ERB テンプレートをそのまま PDF 化 | 確認書・契約書のレイアウトを ERB + Tailwind で書ける（決定B Hotwire+ERB と親和）。日本語フォントは OS 側 | Docker イメージに Chromium + 日本語フォント（Noto CJK）が必要。メモリ消費大。ジョブで生成する前提 |
| prawn（+ prawn-table）| Ruby DSL で PDF 直描画 | 依存が軽い（Chromium 不要）。生成が速い | レイアウトをコードで書く。日本語 TTF の同梱が必要。複雑な帳票は工数増 |

→ 確認書（P3-13）・契約書（P3-8）で **同一の生成 Service（`app/services/documents/pdf_renderer.rb`）を共用**し、テンプレは `app/views/documents/*.html.erb`
（HTML→PDF 案）に置く。選定は R5 着手時（Docker への Chromium 同梱可否＝R8 デプロイ構成と関連）。生成は Solid Queue ジョブ
（`OrderDocumentGenerateJob`。既定キューでよい。決済専用キューには載せない）で非同期化し、完了時に `OrderDocument` を作成→送付ジョブへ。

**既存テーブルとの関係**（Rails版・R4 実装済みの実態で読み替え）:
- `notifications` / `notification_recipients`（**R4 実装済み**。添付は `notification_attachments` テーブルではなく
  `Notification has_many_attached :attachments`＝Active Storage）: 現状の `notifications` は
  `target_type: agency|customer` ＋ フィルタ・スケジュール送信の**一斉通知向け**設計（`NotificationDeliveryJob`）。申込確認メールは
  **案件単発・添付付きのトランザクションメール**であり性質が違う。
  選択肢は (a) `notifications` を単発送信にも流用、(b) イベント駆動のトランザクションメールとして
  **専用 Mailer（`OrderDocumentMailer#confirmation`）+ `deliver_later`** で送り、E2 の宛先ルールは R4 実装済みの
  `RecipientResolver` / `RecipientGroup` を使って解決する（R4 の `InquiryNotifier` + `InquiryMessageMailJob` と同型）、の2つ。
  **R4 通知基盤の設計と分裂させない**ことだけを制約とし、どちらに載せるかは実装計画化時に決める（→ Q-7）。
  Rails版の推奨は (b)（一斉通知の `Notification` レコードを1通のために作るのは不自然。R4 の Inquiry 通知が既に (b) 型）。
- `notification_templates`（**R4 実装済み**）: メール本文テンプレの置き場として流用可能。
  現行の `template_type` は `notification` / `inquiry` / `common` の3値（`NotificationTemplate::TEMPLATE_TYPES`。string + inclusion。enum ではない）。
  申込確認・契約確認用に `application` 等の値を追加する要否は実装時に確認（旧「`type` enum への値追加」の読み替え）。
- `applications`（申込セッション。**R3 実装済み**）: `Form::ApplicationSubmissionService` が申込完了時に `customer_id` / `order_id` / `completed_at`
  を埋め、`form_data` をクリアする実装が既にあるため、確認書生成のトリガは「application 完了 → order 生成後」に置ける。
  ⚠️ ただし **`form_data` は完了時に `{}` へクリアされる**（PII を平文で残さない R3 レビュー対応）。確認書の「申込時点スナップショット」（Q-6）を
  `form_data` から取ることはできず、**生成時に Customer/Store/Order から組み立てて `order_documents.source_snapshot` に固定**する必要がある
  （実装が設計と異なる点。業務上の問題は無いが Q-6 の前提として明記）。

### 3-3. P3-12 と P3-13 の関係

basic-design §6 のフロー上、確認書送付（P3-13）→ 重説チェック（P3-12）の順。確認書の中に重説項目を
含めるかは未確定（→ Q-5）。データ上は独立させ、フロー制御（順序）は P3-4 の状態機械側で持つ。

---

## 4. 実装タイミング（P3 内での位置 ＝ Rails版 R5 内の順序）

計画の実質順序 `P3-1 → P3-2(a〜d,f〜j) → P3-4 → P3-2-e → P3-5〜9`（development-plan §3 P3 注記。Rails版は 04 R5 節の
「状態機械の設計を先に固めてから重説チェックへ着手する」に継承済み）に対して:

| タスク | 置き場所 | 理由 |
|---|---|---|
| P3-12（重説チェック） | **P3-4 の後、P3-5（不備チェック）と並行可** | フロー上の位置（申込確認メール後）を状態遷移条件にするかを P3-4 で決めてから実装する。重説未実施の案件を不備チェックへ進めてよいかが状態機械の論点になるため、P3-4 より先に単独実装すると手戻る。UI 自体は申込フロー（P2 の受注入力画面＝Rails版 R3 `Form::ApplicationsController`。**実装済み**）への差し込みなので P2 完了が前提（**充足済み**） |
| P3-13（確認書） | **P3-8 のPDF生成基盤（ライブラリ選定）確定後、P3-9 と同時期** | 確認書PDFの生成・版数管理は P3-8 で選定するライブラリ（§3-2 表）と版数管理の器（§3-2 `order_documents` 案）を共用するため。送付トリガは申込完了時（P3-2 クレカ登録完了後）なので、P3-2 の完了フック（`PaymentTransaction` の `authorized` 遷移 or 口振/おまとめ選択時は `Application` 完了）にも依存。メール送信の載せ先が R4 通知基盤（旧 P4-14）になる場合は Q-21 確定が前提（`notification-matrix.md` の注記どおり。**R4 で通知基盤は実装済みだが E2 の宛先ルール（Cc要否）は未確定のまま**＝04 R4「未実装ギャップ」） |

- **P3 完了条件への影響**: 現在の完了条件「申込→決済→不備チェック→確認コール→契約確定→契約書発行が
  一気通貫」に、「申込確認メール送付」「重説チェック記録」が含まれるかを明確化すべき
  （basic-design §6 のフローに含まれる以上、含めるのが自然）。
- **状態機械（P3-4）との関係**: basic-design §9 の初期ステータス案は「申込受付」。重説チェック完了を
  「申込受付 → 不備チェック依頼」の遷移条件にするか、記録のみで遷移条件にしないかは P3-4 側の決定事項
  として引き渡す（本書では決めない）。

---

## 5. 未決論点（勝手に決めない）

> 2026-08-19: **Q-1〜9 は `04-rails-implementation-plan.md` R5着手前チェックリストの Q-35「重説チェック・確認書の未決事項（項目/実施者/タイミング/宛先/版管理）」に一括対応**。
> Q-1〜6・Q-8・Q-9 は CEO/業務・法務側の判断待ち、Q-7 は開発側（CTO）で決められる（推奨＝§3-2 (b) 専用 Mailer）。いずれも未解決のまま保持。

| # | 論点 | 確認先 | 関連 |
|---|---|---|---|
| Q-1 | **重説の必須項目は誰が定義するか**（法務? 業務? 項目リスト・文面の確定責任者） | 法務・業務 | release-readiness G-3 / M-7（現行文面が未入手） |
| Q-2 | **重説チェックの実施者・タイミング・方式**（顧客がWeb上でチェック / 営業担当者が口頭説明後に記録 / 併用） | 業務 | basic-design §6 確認中事項④（未確定のまま） |
| Q-3 | 重説チェックの紐づけ単位（案件 `orders`（旧 `jasmin_orders`）単位か、申込セッション `applications` 単位か。差戻し→再申請時に再実施が必要か） | 業務 | P3-6 差戻し |
| Q-4 | 重説未実施の案件をステータス遷移でブロックするか（遷移条件 or 記録のみ） | 業務 → P3-4 へ引き渡し | P3-4 状態機械 |
| Q-5 | **確認書のテンプレは誰が作るか**。現行の「申込書控えPDF」（release-readiness M-6）をそのまま使うのか、新規作成か。確認書に重説項目を含めるか | 業務・法務 | §2 のタイミング不一致（現行は確認コール後送付） |
| Q-6 | 確認書の生成元データ（申込時点スナップショットを保持するか、生成時の最新データか。差戻し修正後の再送付ルール） | 業務 | §3-2 `source_snapshot` |
| Q-7 | 申込確認メールの送信基盤（既存 `notifications` 流用 / R4 通知基盤（旧 P4-14）のイベント E2 として専用 Mailer で実装） | 開発（R5 着手時に決定。Rails版推奨＝§3-2 (b)） | notification-matrix E2 / Q-21 / 04 Q-35 |
| Q-8 | 申込確認メールの Cc 要否（代理店・営業・バックヤード） | 業務 | notification-matrix E2・論点5 |
| Q-9 | 確認書・重説記録の保存期間/削除ポリシー（コンプライアンス証跡としての要件） | 法務 | — |

---

## 6. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-26 | 初版（ドラフト）。レビュー G1/G2 を受け P3-12/13 の定義・境界・現行実態・データモデル案・実装タイミング・未決論点 Q-1〜9 を整理 |
| 2026-08-19 | **Rails版改訂（brige-crm / R5）**。①`jasmin_orders`→`orders`、`jasmin_customer_id`→`customer_id`（決定D）②activitylog→`Auditable`/`AuditLog`（`audit_logs.user_id NOT NULL` の注意）③`file_path`→Active Storage、`notification_attachments`→`has_many_attached`、`type` enum→`TEMPLATE_TYPES` string ④§3-2 に PDF 生成基盤の候補比較（grover/ferrum vs prawn。03§2）と共用 Service 案 ⑤`applications.form_data` が完了時にクリアされる現行実装を Q-6 の前提として明記 ⑥§1/§4 に R3/R4 実装済み・R5 未実装を明記 ⑦Q-1〜9 と 04 Q-35 の対応、Q-7 の Rails版推奨を付記。業務定義・境界・未決論点は変更なし |
