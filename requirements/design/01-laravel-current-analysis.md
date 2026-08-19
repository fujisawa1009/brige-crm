# ジャスミンCRM（Laravel）現行システム分析

- 対象: `projects/boilerplate-vue-env/`（実体は `laravel/` = Gitサブリポジトリ `jasmin_laravel`）
- 目的: brige-crm（Rails）への再構築にあたり、移植すべき機能・ドメインモデル・設計を把握する
- 作成: 2026-08-14（分析エージェントによる調査結果を秘書が整理）

---

## 0. 要点サマリ

- ジャスミンCRM内製化プロジェクト。既存ベンダー（リクリック / 現行 Bridge・BridgePlus）の受注・契約管理を刷新する内製CRM
- **進捗: P0/P1（基盤＋管理画面CRUD）完成、P2（申込フォーム拡張）進行中、P3以降（契約フロー・決済・業務運用）は大半未実装**
- `laravel/requirements/` に要件・設計ドキュメントが非常に充実。**Rails移植では実装コードよりこの要件群が正**
- ⚠️ `AGENTS.md` の「React」記述は誤り。**実体は Vue 3 + Inertia + TypeScript**（テンプレート残骸由来の誤記）

---

## 1. 技術スタック

### バックエンド
- PHP 8.2+ / **Laravel 12** / **Inertia.js**（SPA的サーバサイドルーティング）
- **Fortify**（認証・2FA TOTP）/ **Horizon**（Redisキュー）/ **Reverb**（WebSocket・アプリ内通知リアルタイム配信）
- **spatie/laravel-permission**（RBAC・UUID拡張）/ **spatie/laravel-activitylog**（監査ログ）
- kalnoy/nestedset（**未使用の残骸**）/ maatwebsite/excel（CSV）/ ziggy + Wayfinder（型付きルート）
- テスト: **Pest**

### フロントエンド
- **Vue 3 + TypeScript + Inertia**、SSR対応
- **shadcn-vue**（reka-ui）+ **Tailwind CSS v4** + lucide-vue-next
- vue-i18n（日本語直書き禁止・英語キー）、laravel-echo + pusher-js（Reverb接続）
- Vite 7 + Wayfinder（`resources/js/routes/`・`actions/` に型付きルート自動生成）
- 状態管理は Pinia 等なし（Inertia shared props + ローカルstate）

### DB・インフラ
- **MySQL 8**（utf8mb4）。主キーは**全モデル UUID**（char(36)）
- Docker: app(nginx+PHP) / db / redis / horizon / reverb / scheduler / vite / mailpit / phpmyadmin
- SESSION/CACHE=database、QUEUE=redis、BROADCAST=reverb

---

## 2. ドメインモデル（全39モデル・2026-08-15洗い直しで訂正）

共通トレイト: `HasUuids`（UUID主キー）/ `TracksUser`（created_by/updated_by自動セット）/ spatie `LogsActivity`

### 2-1. 組織・アカウント系

| モデル | テーブル | 要点 |
|---|---|---|
| User | users | 管理画面ログイン（社内/代理店G/代理店）。Fortify 2FA + HasRoles。`is_active`, `agency_group_id`, `agency_id` |
| AgencyGroup | agency_groups | 代理店グループ。`group_code(unique)`, `bridge_plan_display_type`, `csv_download_visible` |
| Agency | agencies | 代理店。`agency_code(unique)`, `email_1〜5`（通知先）, `electronic_contract_enabled` |
| ContractCondition | contract_conditions | **契約条件バージョン**（`effective_from/until`, null=現行）。BridgePlusの「グループ名」相当 |
| SalesRepresentative | sales_representatives | 営業担当者。**受注入力画面の認証キー**（代理店CD＋営業担当者CD） |

### 2-2. 顧客・店舗・案件系（CRM中核）

- **JasminCustomer**（`jasmin_customers`, Authenticatable=マイページログイン主体・customerガード）
  - `customer_number`（`C-000001` 自動採番）、基本情報＋**P2-4拡張37カラム**（契約者情報/担当者1・2/請求書送付先/業種事業情報/外部連携コード netmove_member_id, lbc_code 等）
- **JasminStore**（`jasmin_stores`）: 顧客ぶら下がり店舗。store_code/住所/営業時間/定休日
- **JasminOrder**（`jasmin_orders`）: 案件（受注・契約）。**最大モデル・fillable約90カラム**
  - `order_number`（`ORD{年}{連番4桁}` 自動採番）、プラン/費用、ステータス、日付管理（受注〜検収〜入金〜解約の十数個）、確認コール/検収コール記録、書類・同意、信販9カラム、Bridge移行情報、MEO/GBP系追加サービス多数
- **JasminOrderWorkDetail**（hasOne）: GBP/SNS作業詳細。**SNSアカウント/パスワード平文保持の懸念（Q-D未決・PII論点）**
- **Application**（`applications`）: 申込トランザクション。token(64桁)、完了時に customer/order を一括生成

### 2-3. 商材・マスタ系

- **Product** 1─* **Plan** / **ProductInitialFee** / **ProductOption**、Product 1─1 FormTemplate
- Product *─* Agency（`agency_products`=販売許可）、*─* AgencyGroup
- **OptionGroup / OptionValue**: 階層型選択肢マスタ（`parent_id` 自己参照ツリー。業種>飲食業>ラーメン等）
- **CustomerStatus / OrderStatus**: ステータスDB管理（code/label/is_system）
- **ProductionCompany**（制作会社）、**SalesMaterial**（営業資料・カテゴリ6種）

### 2-4. 申込フォーム定義系

- **FormTemplate / FormStep / FormField**（DB定義）＋ フィールド候補は `Services/FormTemplateDefinition.php` に**ハードコード**
- P2で `target_table`/`target_column`＋3次元編集権限（`editable_by_tier`/`lock_after_status`）へ拡張予定（未反映）

### 2-5. 問い合わせ・通知系

- **Inquiry**（`INQ-000001` 採番、カテゴリ: 後確/制作対応/検収コール/アフター問合せ）1─* **InquiryMessage** 1─* Attachment / Recipient
- **Notification**（一斉メール配信記録・フィルタ・スケジュール送信）1─* Recipient / Attachment、**NotificationTemplate**、**RecipientGroup**
- **SystemNotification**（アプリ内通知・morph・MassPrunable 30日・Reverbリアルタイム）

### 2-6. 決済系（設計先行・骨格のみ）

- **PaymentTransaction**: 厳格な**状態機械**実装済み
  - `PaymentTransactionStatus` Enum: pending/authorized/captured/failed/**unknown**/canceled/refunded + `allowedTransitions()`
  - `mark*`（同期応答起点・unknownから遷移禁止）と `confirm*`（サーバ間確定起点・unknownの唯一の出口）を分離
  - **二重課金防止のため unknown を failed に丸めない**。`existsUnsettledForOrder()` で二重送信防止
- **PaymentTransactionLog**（追記専用・マスク済みbody）
- `Services/Payment/`: NetmoveGateway(interface)/Http・Mock実装/PaymentConfirmationService/Reconciliation系/PaymentLogMasker — **業務フローへの接続は未実装（P3-2）**

### ER関係（要約）

```
AgencyGroup 1─* Agency 1─* SalesRepresentative
                 ├─* ContractCondition (バージョン)
                 └─* JasminCustomer 1─* JasminStore
                                    1─* JasminOrder ─1 JasminOrderWorkDetail
User *─* Role *─* Permission            JasminOrder ─* Inquiry ─* InquiryMessage
Product 1─* Plan/ProductInitialFee/ProductOption ; Product 1─1 FormTemplate 1─* FormStep/FormField
JasminOrder ─1 PaymentTransaction ─* PaymentTransactionLog
Application →(生成) JasminCustomer + JasminOrder
```

---

## 3. ルーティング構成

**全てWebルート（Inertia）。専用APIなし**（JSON補助エンドポイントが管理画面に同居）。

| ファイル | 内容 |
|---|---|
| `web.php` | 管理画面（prefix `admin`、middleware `['auth', 'check.permission']`）。約25エンティティの resource CRUD + 権限管理（`/permissions`, `/permissions/scan`, `/permissions/toggle/{role}`）+ 問い合わせ + CSV + 通知 |
| `auth.php` | 認証（Fortify補完・カスタムregister） |
| `settings.php` | プロフィール/パスワード/2FA/外観 |
| `form.php` | **受注入力画面**（営業担当者・prefix `form`）。代理店CD+営業CD認証 → step1 → 動的 `step/{n}` → complete |
| `mypage.php` | **顧客マイページ**（customerガード）。login + dashboard のみ |
| `horizon.php` | Horizon UIのInertia再実装（Rails移植不要=Sidekiq Web等で代替） |
| `console.php` | スケジュール: 非アクティブ通知(22:10)/CSVクリーンアップ(hourly)/予約通知配信(毎分)/SystemNotification prune(02:00) |

---

## 4. 認証・認可

### 認証は **セッションベース × 3系統**（Sanctum未使用）

1. **管理画面**: guard `web`（User）。Fortify + 2FA(TOTP)。※要件では**メールOTPへ一本化・TOTP廃止予定（Q-19/P4-17）**
2. **顧客マイページ**: guard `customer`（JasminCustomer）。独自SessionController
3. **受注入力**: Laravelガード不使用。**セッション（`form.sales_rep_id`等）＋独自ミドルウェア FormAuth/FormGuest**。認証キー=代理店CD＋営業担当者CD

### 認可（RBAC + 独自ミドルウェア）— ftlogと同型思想

- spatie/laravel-permission。ロール4種（seeder）: **`admin` / `実務運用者` / `代理店グループ用` / `代理店用`**（名称変更禁止指定）
- **`Controller@method` 単位のPermission**を `PermissionScannerService` がコントローラ走査で自動生成
- ミドルウェア `CheckActionPermission` が現在ルートの `Controller@method` で `can()` 判定 → 403
- 権限マトリクス画面（`pages/admin/permissions/matrix.vue`）あり
- 権限はInertia shared propsでフロントへ共有（Cache 10分）
- **レコードレベル参照制御（代理店は自代理店データのみ）は未実装（P4-1・最重要の横断改修）**。InquiryControllerのみ独自スコープで部分実装

→ **ftlogのエンドポイントRBACと同じ発想**（ルート単位権限の自動スキャン＋マトリクスUI）。ftlog側の方が実装が成熟（フェイルクローズ・起動時sync・テストハーネス・Pundit 2層）。

---

## 5. 実装済み機能一覧（業務言語）

### 実装済み（P0/P1）
- ユーザ・アカウント管理（CRUD/有効無効/CSV一括アップロード）
- 認証（ログイン/2FA TOTP/パスワードリセット）・権限管理（ロール・マトリクス・自動スキャン）
- 組織管理（代理店グループ/代理店/営業担当者/契約条件バージョン）
- 顧客管理・店舗管理・案件管理（約90フィールド）
- 商材・プラン・初期費用・オプション管理、販売許可
- マスタ管理（階層選択肢・ステータス）
- **申込フォーム（受注入力）**: 営業ログイン → 商材選択 → 動的マルチステップ → 顧客+店舗+案件+申込を一括生成 → メール/スタッフ通知。フォームビルダー付き
- 問い合わせ管理（メッセージ履歴・添付・宛先解決・テンプレート）
- 通知（一斉メール・スケジュール送信・宛先グループ・**アプリ内通知リアルタイム**）
- 営業資料管理、監査ログ（activitylog）、CSV非同期エクスポート、マイページ（最小）

### 進行中（P2）
- 申込フォームの動的マッピング（`target_table`/`target_column`＋3次元編集権限）
- jasmin_customers 拡張37カラムの画面反映
- 決済の骨格（状態機械済み・フロー接続未）

### 未実装（設計書のみ → Rails側で新規実装）
- クレカ決済連携本体（ネットムーブ・P3-1/2）、手書き署名（P3-3）
- 契約書PDF生成・版数管理・メール送付（P3-8/9）
- **契約ワークフロー**（不備チェック→差戻し→確認コール→契約確定の状態機械、P3-4〜7）
- 入力チェック設定（動的バリデーション・3段階必須、P3-10）、キーワード自動選定（P3-11）
- 重説チェック・申込確認メール（P3-12/13）
- **代理店/グループのレコードレベル参照制御（P4-1）**、顧客横断統合ビュー（P4-2）
- 項目一括更新・顧客名寄せ（P4-3/4）、ftlog移植群（メンション/メールOTP/ログイン履歴等、P4-13〜17）
- 運用機能（遅延検知/自動キャンセル/集計/外部CSV取込/ガルーン連携等、P4-18〜28）
- 掲示板4種→問い合わせ統合（過去42万件は参照アーカイブ・Q-C決定済み）

---

## 6. requirements/ ドキュメント地図（Rails移植の一次資料）

| ファイル | 役割 |
|---|---|
| `requirements/development-plan.md` | **フェーズ管理の単一入口**。実装済み/未実装マトリクス、負債T-1〜5、未決Q一覧、決定者決定D-1〜13 |
| `design/basic-design.md`（1136行） | **機能仕様の正**。18章・項番1-64 |
| `design/Column.md` | スキーマ（カラム）設計の正 |
| `design/payment-integration.md` | ネットムーブ決済設計（リダイレクト型・HMAC-SHA256・非保持/非通過・7状態遷移） |
| `design/business-flow-analysis.md` | 実業務フロー（ステータス35値・申込155項目・必須3段階運用） |
| `design/ftlog-port.md` | ftlogからの機能移植設計（メンション/2FA/通知/監査） |
| `design/legacy-research/`（00-14） | **移行元の正**。現行DB実データ・案件238フィールドマッピング・スキーマギャップ・ETL設計 |
| `design/customer-merge-design.md` ほか | 顧客名寄せ/出力定義/ステータス用語（案件・申込・契約の3語確定）/PII取扱/リリース準備 |

---

## 7. テスト

- **Pest**。Feature: 管理画面CRUD＋認証に約40ファイル（網羅的）。Unit: Models/Services少数
- **偏り（負債T-1）**: 契約フロー・決済・業務ロジック・E2E は未カバー。決済状態機械・申込トランザクションのテスト無し → **Rails側で中核業務テストをゼロから設計する必要**

---

## 8. Rails移植時の設計判断ポイント（原文レポートの要約）

1. **フロントの再選定**: 実体はVue 3 + Inertia（AGENTS.mdのReactは誤記）。Inertia Rails+Vue継続 / Hotwire+ERB / 別SPA の判断が必要
2. **UUID主キー全面採用** → PostgreSQLなら `id: :uuid` が自然。`TracksUser` は CurrentAttributes+コールバックで再現
3. **認証3系統の分離** → Devise複数スコープ＋受注入力は独自セッション認証。2FAはメールOTPで再設計（Q-19。ftlogに実装あり）
4. **権限モデル**: `Controller@method` 動的スキャン方式 → **ftlogのエンドポイントRBACへ置換するのが自然**（同思想でより成熟）。ロール名・運用UI（マトリクス）は維持
5. **レコードレベル参照制御は最初から設計に入れる**（後付けは手戻り大）→ Pundit scope で全一覧・詳細に横断適用
6. **決済状態機械の厳格設計を保持**（unknown≠failed、mark/confirm分離、二重送信防止）
7. **監査ログ**: activitylog → ftlogのAuditable concern or audited/paper_trail。対象カラム定義を移植。保存5年（Q-22）
8. **階層構造**: OptionValueの自己親子ツリーのみ移植（ancestry/closure_tree）。nestedset/organizations画面は**残骸につき移植不要**
9. **契約条件の紐づけ先を受注側へ是正**（負債T-3）。営業担当者CDグローバルユニーク化（T-2）も是正
10. Horizon→Solid Queue/Sidekiq、Reverb→ActionCable、Horizon UI移植は不要
11. フォーム動的定義は**P2拡張後仕様（target_table/column＋3次元編集権限）で最初から作る**
12. バリデーション: インライン中心 → モデルバリデーション＋Form Objectへ整理する好機
13. **自動採番が `count()+1` ベースで競合に弱い** → シーケンス/採番テーブル＋ロックで安全化
14. 顧客テーブルのサービス別分離方針（`jasmin_customers` → 将来 `[service]_customers`＋横断UNION）を踏襲するか要判断
15. **PII平文保持**（WorkDetailのSNS認証情報）→ `ActiveRecord::Encryption` 等の暗号化を検討（Q-D）
16. **データ移行が前提**（現行DB全件・掲示板42万件）。新スキーマは `legacy-research/11-order-field-mapping.md`（案件238フィールド）と整合させること
