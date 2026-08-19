# 基本設計書

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/basic-design.md）を brige-crm（Rails 8.1）の現行実装（`db/schema.rb` / `app/models` / `app/controllers` / `app/policies` / `config/routes.rb`）・03-rails-architecture-proposal.md（決定A〜F・§8-2）・04-rails-implementation-plan.md（R0〜R8）に合わせて全面見直し。フェーズ対応: §1〜5・§15〜18 = R0〜R4（実装済み範囲。章ごとに「実装済み（Rx）」「実装が異なる（差分）」を注記）、§6〜14 = R5（契約フロー・決済。未実装。Rails版での実装方針を追記）。
> 最終更新: 2026-08-19（Rails版改訂）／旧Laravel版最終更新: 2026-05-15
> ステータス: 機能仕様の正（brige-crm `requirements/` が正。旧Laravel側は凍結参照元）。要件追加により随時更新
>
> **本書の位置づけ（Rails版）**: 業務要件・項番・未決論点は旧Laravel版から引き継ぎ、実装記述のみ Rails 版（Hotwire+ERB / PostgreSQL+UUID / Devise+メールOTP / ftlog式エンドポイントRBAC+Pundit / Solid Queue・Cache・Cable / ActionMailer）へ読み替えた。実装と設計が異なる箇所は原則「実装を正として設計を追従」させ、業務要件上の懸念があるものは「要確認」として残している。テーブル・カラムの詳細は `Column.md`、フェーズ計画は `04-rails-implementation-plan.md` を参照。

---

## 目次

1. [ユーザ管理](#1-ユーザ管理)
2. [ログイン管理](#2-ログイン管理)
3. [権限管理](#3-権限管理)
4. [顧客一覧](#4-顧客一覧)
5. [顧客詳細](#5-顧客詳細)
6. [申込登録](#6-申込登録)
7. [決済連携](#7-決済連携)
8. [入力チェック設定](#8-入力チェック設定)
9. [不備チェック](#9-不備チェック)
10. [差戻し](#10-差戻し)
11. [キーワード選定](#11-キーワード選定)
12. [確認コール](#12-確認コール)
13. [契約書作成](#13-契約書作成)
14. [契約書参照](#14-契約書参照)
15. [案件一覧（Bridge管理 / BridgePlus管理）](#15-案件一覧bridge管理--bridgeplus管理)
16. [監査ログ](#16-監査ログ)
17. [問い合わせ管理](#17-問い合わせ管理)
18. [選択肢マスタ管理](#18-選択肢マスタ管理)

---

## 凡例

| 列 | 説明 |
|---|---|
| 項番 | 要件識別番号 |
| 必須 | 〇：必須要件 |
| CRUD/B | C=作成, R=参照, U=更新, D=削除, B=バッチ |
| 出力 | 処理結果の出力先 |

**実装状況ラベル（Rails版改訂で追加）**

| ラベル | 意味 |
|---|---|
| ✅ 実装済み（Rx） | brige-crm の当該フェーズで実装済み。参照先は `app/` 配下の実装ファイル |
| ⚠️ 差分 | 実装済みだが本書の記述と異なる。原則実装を正とし、業務要件上の懸念は「要確認」 |
| ⏳ 未実装（Rx） | 未着手。実施予定フェーズを併記。Rails版での実装方針を記載 |

**認証・認可の全体像（Rails版。03§3・§4 準拠）**

| 系統 | section（決定C） | 認証 | 認可 |
|---|---|---|---|
| 管理画面（社内 / 代理店グループ / 代理店） | `admin` | Devise `User`（database_authenticatable / recoverable / lockable / timeoutable）+ メールOTP（`OtpAuthenticatable` concern: otp_code_digest SHA256・10分・5回）+ rack-attack + IP許可リスト（`IpAllowlistEntry`。一致時のみOTP免除、空リスト=全員OTP必須） | レイヤー1: エンドポイントRBAC（`SystemPermission` / `SystemRole` / `SystemRolePermission` / `UserSystemRole` + `SystemPermissionChecker`。`ApplicationController` でフェイルクローズ）。レイヤー2: Pundit `policy_scope`（`AgencyScoped` concern: 代理店=自代理店のみ / グループ=配下のみ / 社内=全件） |
| 受注入力（営業担当者） | `form` | 独自セッション（代理店CD＋営業担当者CD → `Form::SessionsController`）+ メールOTP（`Form::OtpsController`）。`SalesRepresentative` は Devise 対象外。`authorize_system_permission!` はスキップし `FormAuthenticatable` concern のみで保護（03§8-2 方式b） | 営業担当者はロールを持たない（section 固定運用） |
| 顧客マイページ（Customer） | `mypage` | Devise `Customer` 別スコープ（database_authenticatable / lockable / timeoutable。registerable・recoverable は意図的に外す）+ メールOTP（`Mypage::OtpsController`） | 顧客はロールを持たない（section 固定運用） |

---

## 1. ユーザ管理

### 1-1. ユーザ情報登録編集

| 項目 | 内容 |
|---|---|
| **項番** | 1 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | U |
| **出力** | 画面 / DB更新 |

**処理内容**

管理者が以下のユーザアカウントを登録・編集できるようにする。
登録時に氏名、メールアドレス、権限種別、所属情報等を設定可能とする。

| 対象 | 説明 |
|---|---|
| 社内ユーザ（FTG・BW） | 個別メールアドレスをユーザIDとするアカウント |
| 代理店グループ用アカウント | 代理店グループ単位（1グループ＝1アカウント）で管理するログイン用アカウント |
| 代理店用アカウント | 代理店単位（1代理店＝1アカウント）で管理するログイン用アカウント |

> **注意：** 実際の営業担当者情報（氏名・担当者CD等）は営業担当者テーブルで別途管理する。ユーザ管理画面で登録する代理店側のアカウントはログイン用アカウントのみ。

**所属関係**

- 代理店グループ用アカウント：代理店グループ（グループCD）に属する
- 代理店用アカウント：代理店（代理店CD）に属する
- 営業担当者：代理店 ＜ 代理店グループに属する

**補足：ログイン処理の3系統（Rails版で「2系統＋顧客マイページ」に整理。03§4）**

本システムはログイン処理を以下の3系統で管理する（旧Laravel版では2系統と記載していたが、R4で顧客マイページを追加したため3系統として整理）。

| 系統 | 対象画面 | 認証方式 | 認証テーブル / 実装 |
|---|---|---|---|
| 管理画面ログイン | 管理画面全般（`/admin/*`） | メールアドレス＋PW＋メールOTP | `users`（Devise `User` + `OtpAuthenticatable`。ロール権限制御は `user_system_roles`） |
| 受注入力画面ログイン | 受注情報入力画面（`/form/*`） | 代理店CD ＋ 営業担当者CD＋メールOTP | `sales_representatives`（`Form::SessionsController` / `Form::OtpsController`。独自セッション） |
| 顧客マイページログイン | マイページ（`/mypage/*`） | メールアドレス＋PW＋メールOTP | `customers`（Devise `Customer` 別スコープ + `OtpAuthenticatable`） |

受注入力画面を独立した認証系統とする理由：
- 受注入力画面では顧客情報等の参照を行わない（入力専用フロー）
- 外部決済会社への連携および管理画面側での受注契約データ作成が完了するまでの閉じたフローとして位置づける
- 管理画面の権限制御と切り離すことで、受注フローを簡潔に保つ
- （Rails版補足）`SalesRepresentative` は Devise・STI 判定に乗らないため、`form` 名前空間は `authorize_system_permission!` を完全スキップし `FormAuthenticatable` concern のみで保護する（03§8-2 決定b）

> **移行方針：** 従来のチーム単位の共通アカウントによるログインは廃止し、個別メールアドレス単位のアカウント管理に移行する。

**実装状況**

> ✅ **実装済み（R0/R1）**: `Admin::UsersController`（CRUD）・`app/models/user.rb`。ユーザは `users.agency_group_id` / `users.agency_id` で所属を表現し、**両方同時設定は不可**（`User#agency_scope_is_exclusive`。社内ユーザは両方NULL）。権限種別は `SystemRole`（組み込み4ロール: `admin`（super_admin）/ `実務運用者` / `代理店グループ用` / `代理店用`。名称維持）を `UserSystemRole` で多対多割当。
> ✅ **実装済み（R1）**: ユーザCSV一括アップロード（`Admin::UsersController#import` / `#import_upload` → `UserCsvImportJob`・Solid Queue 非同期）。※インポート結果の履歴永続化・UI表示は未実装（04 R1見直し残タスク）。
> ⚠️ **差分**: 「所属部署」（社内ユーザ）は `users` にカラムを持たない（部署マスタは未実装。R6以降で必要性判断）。代理店・代理店グループ用アカウントは「1組織＝1アカウント」の運用を強制していない（複数ユーザを同一 `agency_id` に紐づけ可能。業務上の制約は運用ルール）。

---

### 1-2. ユーザ一覧・検索

| 項目 | 内容 |
|---|---|
| **項番** | 2 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |

**処理内容**

登録済みユーザを一覧表示し、以下の条件で検索・絞込可能とする。

- 氏名
- メールアドレス
- 権限種別
- 所属代理店
- 状態

**実装状況**

> ✅ **実装済み（R1）**: `Admin::UsersController#index`（`policy_scope(User)` でロール・所属に応じた一覧）。
> ⚠️ **差分**: 現状の一覧は `email` 順の全件表示のみで、上記の検索・絞込条件（氏名 / メール / 権限種別 / 所属代理店 / 状態）とページネーション（pagy）は未実装。Customer/Order 一覧と同じ `q` パラメータ方式で追加する（R6 運用強化で対応。要件自体は維持）。

---

### 1-3. ユーザ無効化

| 項目 | 内容 |
|---|---|
| **項番** | 3 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | U |
| **出力** | 画面 / DB更新 |

**処理内容**

管理者が登録済みユーザを無効化できるようにする。無効化されたユーザはログイン不可とする。

**実装状況・追加対応事項**

> ✅ **実装済み（R1）**（旧Laravel版では「未実装」だった項目。Rails版で解消）:
> - `users.is_active`（boolean, default true）を保持
> - `User#active_for_authentication?` を上書きし、`is_active=false` のユーザは Devise 認証で拒否（メッセージは Devise 既定の `:inactive`）
> - `Auditable::TRACKED_FIELDS["User"]` に `is_active` を含め、無効化操作は監査ログに差分記録される
> - 無効化は編集画面の `is_active` チェックボックスで行う（`Admin::UsersController#update`）。物理削除（`#destroy`）も残しているが、業務運用は無効化を基本とする
>
> ⚠️ **要確認**: 旧記述の「無効化ボタン（物理削除ボタンとの分離）」は専用ボタンではなく編集フォーム内フラグとして実装。UI上の分離が業務要件として必要かは運用開始前に確認。

---

## 2. ログイン管理

### 2-1. パスワード再設定

| 項目 | 内容 |
|---|---|
| **項番** | 4 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

社内ユーザおよび代理店営業担当者が、登録済みメールアドレスを用いてパスワード再設定を行えるようにする。

**実装状況**

> ✅ **実装済み（R0）**: 管理画面ユーザ（`User`）は Devise `:recoverable`（`users.reset_password_token` / `reset_password_sent_at`）。再設定メールは `send_devise_notification` → `deliver_later`（Solid Queue）で非同期送信。rack-attack で `password_resets/email` を 15分3回に制限。再設定要求・完了・失敗は `AuthAuditable`（`password_reset_requested` / `password_reset_completed` / `password_reset_failed`）で監査ログに記録。
> ⚠️ **差分**: 「代理店営業担当者」（`SalesRepresentative`）はパスワードを持たない（代理店CD＋営業担当者CD＋メールOTPで認証。§1-1）ため、営業担当者向けのパスワード再設定は**対象外**。本項の対象は「管理画面ユーザ（社内・代理店グループ・代理店アカウント）」と読み替える。
> ⚠️ **差分**: 顧客マイページ（`Customer`）は `:recoverable` を意図的に外している（R3 の申込トランザクションがパスワード無しで Customer を生成するため。`app/models/customer.rb` コメント参照）。顧客向けパスワード再設定はマイページ本格化時（R6 以降）に別途要件化する。

---

### 2-2. セッション管理

| 項目 | 内容 |
|---|---|
| **項番** | 34 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

ログイン後のセッションを管理し、未認証状態では保護対象画面へアクセス不可とする。ログアウト時はセッションを無効化する。

**実装状況**

> ✅ **実装済み（R0/R3/R4）**:
> - 管理画面: Devise `:timeoutable`（`User`）。Devise セッションはパスワード照合時点では確立せず、**メールOTP 照合成功後にのみ `sign_in`**（`Users::SessionsController` / `Users::OtpsController`。OTP 未完了で保護画面に到達できない）。`ApplicationController` の before_action は 認証（`authenticate_user!`）→ `Current` 確定（`set_current_attributes`）→ 認可（`authorize_system_permission!`。フェイルクローズ）の順。
> - 受注入力: `session[:form_sales_representative_id]` による独自セッション（`FormAuthenticatable`）。ログアウトは `Form::SessionsController#destroy` で `reset_session`。ログイン中に `is_active=false` になった営業担当者は次アクセスで弾かれる（`SalesRepresentative.active` で再検索）。
> - マイページ: Devise `:timeoutable`（`Customer`）。退会済み（`CustomerStatus::CODE_WITHDRAWN`）はログイン不可（`Customer#active_for_authentication?`）。
>
> ⚠️ **差分 / 残タスク（04 R3見直し）**: セッション絶対有効期限（`expire_after`）と `config.force_ssl = true`（本番）が未設定、営業担当者ログイン成功時の `session` ID 再生成が未実施。R8（リリース準備）までに対応する。

---

### 2-3. 認証失敗制御

| 項目 | 内容 |
|---|---|
| **項番** | 35 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

一定回数以上ログイン認証に失敗した場合は、一時的に認証を制限可能とする。

**実装状況**

> ✅ **実装済み（R0/R4）**: Devise `:lockable`（`User`: `failed_attempts` / `locked_at` / `unlock_token`。`Customer`: `lock_strategy: :failed_attempts, maximum_attempts: 5, unlock_strategy: :time`）。ロック発生は監査ログ `account_locked`、失敗は `login_failed` に記録（`AuthAuditable`）。加えて rack-attack でIP単位のスロットリング（OTP照合・再送・パスワード再設定）。
> ⚠️ **差分**: 受注入力（`SalesRepresentative`）はパスワードを持たないため Devise lockable の対象外。OTP試行回数上限（5回）と rack-attack のIPスロットリングで代替している。代理店CD＋営業担当者CDの総当たり対策として専用スロットル追加の要否は R8 のセキュリティ確認で判断。

---

### 2-4. 二要素認証（メールOTP）・IP許可リスト（Rails版で追加）

| 項目 | 内容 |
|---|---|
| **項番** | 34-2（Rails版追加。development-plan Q-19 / Q-23 / P4-17） |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U |
| **出力** | 画面 / DB更新 / メール |

**処理内容**

全画面（管理画面・受注入力・マイページ）でログイン後にメールOTPによる二要素認証を必須とする（development-plan Q-23「全画面必須」・CEO決定 2026-07-26。TOTP方式は Q-19 で廃止しメールOTPに統一）。接続元IPが IP許可リストに一致する場合のみOTPを免除できる。

**実装状況**

> ✅ **実装済み（R0: User / R3: SalesRepresentative / R4: Customer）**: `OtpAuthenticatable` concern（`otp_code_digest` SHA256・有効期限10分・試行5回・`secure_compare`）を3モデルに横展開。送信は `OtpMailer#login_code` / `#form_login_code` / `#mypage_login_code`（`deliver_later`）。照合画面は `Users::OtpsController` / `Form::OtpsController` / `Mypage::OtpsController`。発行・照合成功・失敗は監査ログ（`otp_issued` / `otp_verified` / `otp_failed`）。rack-attack で `otp_verify/ip` 15分10回・`otp_resend/ip` 15分3回を制限。
> ✅ **実装済み（R0）**: IP許可リスト `IpAllowlistEntry`（`cidr` / `note`。`Admin::IpAllowlistEntriesController`。admin ロールのみ）。**空リスト時は必ず false を返すフェイルセーフ**（未設定なら全員OTP必須）。管理画面（`Users::SessionsController`）と受注入力（`Form::SessionsController`）の双方で同じ判定を適用（非対称は 2026-08-17 に是正済み）。
> ⚠️ **要確認**: マイページ（Customer）側にはIP許可リストによるOTP免除を適用していない（顧客は不特定IPからの利用が前提のため意図的）。業務側でマイページ側の免除要否を確認。

---

## 3. 権限管理

### 3-1. 所属代理店・所属部署紐づけ管理

| 項目 | 内容 |
|---|---|
| **項番** | 5 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

ユーザの種別に応じて以下の所属情報を紐づけて管理する。参照・更新可能範囲は所属情報および担当紐づけ情報をもとに判定する。

| ユーザ種別 | 紐づける所属情報 |
|---|---|
| 代理店グループ用アカウント | グループCD（代理店グループ） |
| 代理店用アカウント | 代理店CD（個別代理店） |
| 社内ユーザ（FTG・BW） | 所属部署 |

**ロール別参照範囲**

| ロール | 参照範囲 |
|---|---|
| 管理者 | 全データを参照可能 |
| 実務運用者（FTG・BW） | 一部制限あり（詳細は別途定義） |
| 代理店グループ用アカウント | グループCD配下の全代理店に紐づく顧客・受注を参照可能（基本編集不可） |
| 代理店用アカウント | 該当代理店CD（全契約条件バージョン）に紐づく顧客・受注のみ参照可能（基本編集不可） |

> ✅ **実装済み（R0/R1）**: 上記4ロールは `SystemRole::BUILT_IN_ROLE_ATTRIBUTES`（`admin` / `実務運用者` / `代理店グループ用` / `代理店用`）として組み込み（削除不可・名称変更不可）。参照範囲は `AgencyScoped`（`staff_scope` / `agency_group_scope` / `agency_scope`）で判定。
> ⚠️ **差分 / 要確認**: 「実務運用者（FTG・BW）: 一部制限あり（詳細は別途定義）」は、参照範囲は社内ユーザとして**全件**（`staff_scope`）、操作制限は `RoleSeeder` の既定マトリクス（ロール管理・権限管理・ログイン履歴・IP許可リストは admin のみ、それ以外のCRUDは可）で表現している。「一部制限」の業務定義は未確定のまま。運用開始前に業務側で確定し、権限マトリクス画面で調整する。
> ⚠️ **差分**: 「所属部署」（社内ユーザ）のカラム・マスタは未実装（§1-1 参照）。

**代理店・代理店グループアカウントの権限設計方針（Rails版: 2層認可。03§3）**

- 代理店・代理店グループのユーザは**固定権限**（ロール種別はアカウント種別で自動決定し、個別に権限を変更しない）
  - レイヤー1（操作可否）: エンドポイントRBAC。`SystemPermission`（ルート署名 controller/action/http_method/path/section）× `SystemRole`（組み込み4ロール `admin`（super_admin）/ `実務運用者` / `代理店グループ用` / `代理店用`。名称維持）を `SystemRolePermission` で結び、`UserSystemRole` でユーザに割当。`RoleSeeder` が既定マトリクスをコードで宣言し、`SystemPermissionSyncService` が起動時にルーティングテーブルを走査してカタログを自動同期。`ApplicationController` の `authorize_system_permission!` はフェイルクローズ（未登録ルート・未割当は403、`permission_denied` を監査ログ記録）。権限マトリクス画面（`Admin::PermissionManagementController`）・ロール管理画面（`Admin::RoleManagementController`）は admin ロールのみ
  - レイヤー2（レコード可否・参照スコープ）: Pundit。`app/policies/concerns/agency_scoped.rb` の `AgencyScoped` を各 Policy（Customer / Store / Order / Inquiry / SalesRepresentative / ContractCondition / User ほか）が include し、`policy_scope` で一覧・詳細・更新を絞り込む
- レコードレベルのアクセス制御は、ログインユーザの所属（`users.agency_id` / `users.agency_group_id`）とレコードのキーの一致で判定する

```
社内ユーザ（admin / 実務運用者）: users.agency_id = NULL かつ users.agency_group_id = NULL
    → staff_scope: 全件

代理店アカウント: users.agency_id = agencies.id
    → agency_scope: レコードの agency_id が一致するもののみ（例: customers.agency_id / orders.agency_id）

代理店グループアカウント: users.agency_group_id = agency_groups.id
    → agency_group_scope: レコードの agency → agencies.agency_group_id が一致するもの（配下の全代理店）
```

- 更新時に `agency_id` / `customer_id` 等の所有権パラメータを付け替えて越境する経路は `strip_ownership_params!` で遮断（`Admin::CustomersController#update` 等）
- 「基本編集不可」（旧記述）は、Rails版では **見える範囲=Punditスコープ、押せる操作=ロール割当** の分担で表現する（決定C。section は増やさない）。代理店/グループロールにどの操作（update/destroy）を許すかは `RoleSeeder` の既定マトリクスと権限マトリクス画面で管理する

**ログイン方式**

| アカウント種別 | ログイン方式 | テーブル |
|---|---|---|
| 管理画面（社内・代理店・代理店グループ） | メールアドレス + パスワード + メールOTP | `users` |
| 受注入力画面（営業担当者） | 代理店CD ＋ 営業担当者CD + メールOTP | `sales_representatives` |
| 顧客マイページ | メールアドレス + パスワード + メールOTP | `customers` |

> ✅ **解消済み（Rails版 R1）**: 旧記述「現行実装との差異あり（2026-07-27）: `organizations` テーブル前提の旧記述が残る（development-plan T-6 / Q-31）」は、Rails版で `agency_groups` / `agencies` / `users.agency_group_id` / `users.agency_id` 直管理として実装したことで解消。`organizations` テーブル・Nested Set（kalnoy/nestedset）は **持ち込まない**（03§5「Laravel現行の未使用残骸は持ち込まない」）。

> ⚠️ **未確認（継続）**: BridgePlus代理店のアカウント用ログインメールアドレスを通知先メール（`agencies.email_1〜5`）のいずれかで兼用するか、別途専用フィールドが必要かは要確認。現行実装では `users.email`（ログイン用）と `agencies.email_1〜5`（通知先）は独立しており、兼用の自動同期は行っていない。

**代理店CD・グループCD・契約条件の設計方針**

代理店CDは固定（契約条件変更があっても新規発番しない）。契約条件のみバージョン管理する。

```
代理店グループ（グループCD: 固定・不変）
  └── 代理店（代理店CD: 固定・不変）
       └── 契約条件 v1（〜2024/03）← 過去受注はここに紐づいたまま
       └── 契約条件 v2（2024/04〜） ← 新規受注はここに紐づく

受注 → 受注時点の契約条件バージョンIDに紐づく
```

- **グループCD**：代理店グループの識別子。不変。
- **代理店CD**：個別代理店の識別子。契約条件が変わっても変わらない。
- **契約条件**：代理店に紐づき、バージョン（適用期間）ごとに管理する。
- **受注レコード**：受注作成時点の契約条件バージョンIDに紐づく（代理店CDへの直接紐づけは不要）。

> **[契約条件とは]** BridgePlus案件一覧のグループ名（例：株式会社壱（取次））に相当するもの。受注時にその時点で代理店が保持する有効な契約条件バージョンが自動的に紐づく。

**実装状況・追加対応事項**

> ✅ **実装済み（R1）**: 参照範囲制御（旧記述では「未実装」）は Pundit `policy_scope`（`AgencyScoped`）で **全一覧・詳細・更新に最初から適用**（04 R1「以降の全エンティティで必須」）。代理店ユーザで他代理店の Customer/Order に到達できないことは request spec（`spec/requests/admin/*`）で検証済み（R2完了条件）。

**実装スキーマ（Rails版。旧「既存リポジトリへの追加作業」①〜⑥を現行 `db/schema.rb` に置き換え）**

> 旧Laravel版は「Nested Set（kalnoy/nestedset）の `organizations` テーブルを基盤に、①`organization_type` 追加 → ②〜⑤ 各専用テーブルを 1:1 で新設」という増築案だった。Rails版では `organizations` を持たず、以下の独立テーブルを直接持つ（決定D・03§5）。主キーは全て UUID（`gen_random_uuid()`）。全テーブルに `created_by_id` / `updated_by_id`（`TracksUser` concern・`Current.user` から自動セット）と `created_at` / `updated_at` を持つ（以下の表では省略）。

**① `organizations` テーブル** — ⚠️ **差分: 廃止（作成しない）**。組織種別は各テーブルの存在そのもので表現する。

**② `agency_groups`（代理店グループ）** — ✅ 実装済み（R1）。`Admin::AgencyGroupsController`

| カラム | 型 | 内容 |
|---|---|---|
| `id` | UUID | 主キー |
| `group_code` | string (unique, not null) | 業務上のグループCD。ログインIDと常に同値。固定・不変 |
| `name` | string (not null) | グループ名（Rails版で追加。旧設計は organizations.name に依存していた） |
| `service_type` | string (not null) | サービス種別（Bridge / BridgePlus。Rails版で追加。`bridge_plan_display_type` / `csv_download_visible` の使い分けをこの列で判定） |
| `contact_email` | string / null | グループ連絡先メール（Bridge: グループアカウントメールアドレス / BridgePlus: 担当メールアドレス） |
| `bridge_plan_display_type` | string / null | #Bridgeプラン表示区分。値: `ハイブリッド` / `プラン全表示`（enum ではなく string で保持） |
| `csv_download_visible` | boolean / null | CSVダウンロードボタン表示フラグ（Bridge側のみ使用。BridgePlus側はNULL） |
| ~~`organization_id`~~ | - | 廃止（organizations を持たないため） |

**③ `agencies`（代理店）** — ✅ 実装済み（R1）。`Admin::AgenciesController`

| カラム | 型 | 内容 |
|---|---|---|
| `id` | UUID | 主キー |
| `agency_group_id` | UUID (FK, not null, on_delete restrict) | 所属代理店グループ（旧 organizations 親子関係の代替。1代理店は必ず1グループに属する） |
| `agency_code` | string (unique, not null) | 業務上の代理店CD。ログインIDと常に同値。固定・不変 |
| `name` | string (not null) | 代理店名（Rails版で追加） |
| `contact_person` | string / null | 店所担当者名（Bridge: 担当者 / BridgePlus: 店所担当者。同一概念） |
| `email_1`〜`email_5` | string / null | 通知先メールアドレス（申込・ステータス変更等の送付先）。現データでは最大3件使用。将来的に別テーブルへの切り出しを検討 |
| `electronic_contract_enabled` | boolean / null | 電子契約フラグ（Bridge側のみ。true=利用可能 / false=利用不可。BridgePlus側はNULL）。§13 契約書作成（R5）で参照予定 |
| `csv_download_visible` | boolean / null | CSVダウンロードボタン表示フラグ（Bridge側のみ。BridgePlus側はNULL） |

> ⚠️ **設計課題（継続）：グループ兼代理店**
> BridgePlus側でグループCDと代理店CDが同一の会社（Meta Sales・壱取次・Bond・グライナー・KGpartners）が存在する。Rails版では Nested Set を持たないため、**「1グループ＋配下1代理店（同一CD）」の2レコードで表現**するのが現行スキーマ上の自然な表現（`Column.md` 参照）。Bridge側データ受領後・R7データ移行設計時に最終確定。
> ⚠️ **要確認（Q-移7）**: `agencies` に住所・電話カラムが無い（代理店の住所管理の要否が未決。04 R7）。
> ⚠️ **未実装UI（R2見直し残タスク）**: 販売許可（`agency_products` / `agency_group_products`: Product×Agency/AgencyGroup 中間）はモデル・`Product.sellable_by` のみ実装済みで、管理画面から付与・剥奪する UI が無い。R6 で `product_ids` 同期アクションを追加予定。

**④ `contract_conditions`（契約条件バージョン管理）** — ✅ 実装済み（R1）。`Admin::ContractConditionsController`

| カラム | 型 | 内容 |
|---|---|---|
| `id` | UUID | 主キー |
| `agency_id` | UUID (FK, not null) | agencies.id への参照 |
| `name` | string (not null) | 契約条件名（グループ名）例：株式会社壱（取次） |
| `effective_from` | date (not null) | 適用開始日 |
| `effective_until` | date / null | 適用終了日（NULLは現行バージョン。index あり） |
| ※その他 | - | 契約条件の詳細属性（手数料率等）は別途定義。R5/R6 で追加判断 |

**⑤ `sales_representatives`（営業担当者）** — ✅ 実装済み（R1/R3）。`Admin::SalesRepresentativesController`。受注入力画面の認証主体（Devise対象外）

| カラム | 型 | 内容 |
|---|---|---|
| `id` | UUID | 主キー |
| `agency_id` | UUID (FK, not null) | 所属代理店（旧 `organization_id` の代替） |
| `sales_rep_code` | string (unique, not null) | 営業担当者CD。**システム全体でグローバルユニーク**（例: 980293〜980324）。代理店CD と組み合わせて受注入力画面のログインキーとなる。✅ **T-2 是正済み**（旧Laravelの `(organization_id, sales_rep_code)` 複合ユニークを単独ユニークに変更） |
| `name` | string (not null) | 氏名 |
| `email` | string / null | メールOTP送信先（Rails版で追加。Q-23 全画面2FA対応。未設定の営業担当者は受注入力にログインできない＝運用不備として扱う） |
| `otp_code_digest` / `otp_code_expires_at` / `otp_attempts` | string / datetime / integer | メールOTP（`OtpAuthenticatable`。Rails版で追加） |
| `pdf_store_name` | string / null | PDF出力用店所名（契約書等に印刷。組織マスタとは独立した自由入力テキスト） |
| `pdf_postal_code` | string / null | PDF出力用郵便番号 |
| `pdf_prefecture` | string / null | PDF出力用都道府県 |
| `pdf_city` | string / null | PDF出力用市区郡 |
| `pdf_town` | string / null | PDF出力用町名 |
| `pdf_address_detail` | string / null | PDF出力用番地・ビル・建物 |
| `pdf_phone_number` | string / null | PDF出力用電話番号 |
| `pdf_fax_number` | string / null | PDF出力用FAX番号 |
| `is_active` | boolean (not null, default true) | 有効フラグ（false: ログイン不可。ログイン中でも次アクセスで強制ログアウト） |

> `pdf_postal_code`〜`pdf_fax_number` は**Bridge側のみ**。BridgePlus側は全カラムNULL。§13 契約書PDF（R5）で参照予定。

**⑥ 受注テーブル（`orders`）への外部キー** — ✅ 実装済み（R2）。**T-3 是正済み**（契約条件は顧客ではなく受注側に持つ）

| カラム | 型 | 内容 |
|---|---|---|
| `contract_condition_id` | UUID (FK, not null) | 受注時点の契約条件バージョンIDを保持 |

受注作成時に代理店の有効な契約条件バージョン（`effective_until IS NULL`）を自動取得して紐づける（申込フォーム経由: `Form::ApplicationSubmissionService#current_contract_condition!`。有効な契約条件が無い代理店は申込完了できない）。

**⑦ `users` の所属カラム（Rails版で明記）** — ✅ 実装済み（R1）

| カラム | 型 | 内容 |
|---|---|---|
| `agency_group_id` | UUID (FK, on_delete restrict) / null | 代理店グループ用アカウントの所属。`agency_id` と同時設定不可 |
| `agency_id` | UUID (FK, on_delete restrict) / null | 代理店用アカウントの所属。`agency_group_id` と同時設定不可 |

> Agency / AgencyGroup 削除時にユーザが所属を失って社内ユーザ扱い（全件参照）へ昇格するバグは `on_delete: :restrict` で防止済み（04 R1見直し・commit `1e7a0ad`）。

---

## 4. 顧客一覧

### 設計方針：サービス別顧客テーブル（Rails版: 決定Dにより `customers` へ正規化）

旧Laravel版では「顧客テーブルはサービスごとに分離し、本システムは **`jasmin_customers`**、将来サービスは `[service]_customers`」とする方針だった。

> ✅ **Rails版（決定D・03§8 / §8-2 D-補足）**: `jasmin_` プレフィックスを外し、テーブル名 **`customers`**・モデル名 **`Customer`** で実装（R2）。新規サービス名称（プロダクト名）は未定で、名称確定後も内部モデル名は汎用名を維持する。将来サービス別分離が必要になった場合は **テーブル名プレフィックスではなく Rails の namespace（モジュール）で対応**する。
> 「Customer が契約主体とマイページログイン主体を兼ねている」点（T-4）は設計負債として認識済みで、再分割要否は R2完了後に CEO へ提案する形で持ち越し（03§8-2）。

```
customers            ← 本システムの顧客（Devise Customer スコープ = マイページログイン主体を兼ねる）
[将来サービス]        ← namespace で分離（例: OtherService::Customer）。テーブル名プレフィックスは使わない
```

**この方針によるメリット・注意点**

- 各サービスが独立したスキーマ設計・カラム追加が可能
- 同一人物が複数サービスに登録される場合、各テーブルに別レコードとして管理される
- 代理店CDは `customers.agency_id`（agencies への FK）として保持し、参照範囲制御（Pundit `CustomerPolicy::Scope`）に使用する
- ✅ 顧客番号 `customer_number`（`C-000001` 形式）は `SequenceCounter`（PostgreSQL 単一 UPSERT でアトミック採番）で払い出す。Laravel現行の `count()+1` 方式（T-1系の重複脆弱性）は採用しない。並行作成でも重複しないことを spec で検証済み

---

### 設計方針：顧客一覧の統合表示（暫定）

> ⚠️ **保留中（担当者確認中）**
> 以下の確認事項が未解決のため、顧客・店舗テーブルの統合・分離方針は保留とする。確認結果が得られ次第、方針を確定する。
>
> | # | 確認事項 |
> |---|---|
> | ① | 現行システムで同一顧客・同一店舗に商材をまたいだ共通IDが存在するか |
> | ② | 現在、複数商材を同時に契約している店舗が実際に存在するか |

**方針：テーブルは商材ごとに分離、一覧表示は商材横断で統合する**

管理者・代理店担当者が複数商材の顧客を同時に管理するニーズがあるため、顧客一覧は商材横断の統合ビューとして提供する。各商材のテーブルスキーマは独立して保ちつつ、共通カラムをUNIONで統合して表示する。

```
顧客一覧（統合ビュー）
  └── customers（本システム商材）
  └── [将来サービス]::Customer（他商材）
       ↑ 共通カラムをUNIONで統合・商材種別カラムで判別

顧客詳細（商材ごと）
  └── 各テーブルの商材固有フィールドを表示
```

> ⏳ **未実装（R6）**: 商材横断の統合ビュー（顧客横断統合ビュー・名寄せ）は 04 R6「運用強化」の範囲。現行 R2 は単一 `customers` テーブルの一覧のみ。名寄せ設計は `customer-merge-design.md`（高リスク並行処理は request spec 必須）。

**統合一覧に必要な共通カラム（暫定）**

| カラム | 備考 |
|---|---|
| 商材種別 | どの商材の顧客か判別するフラグ |
| FTWEB顧客番号 | 商材ごとに採番 |
| 顧客名 | |
| グループ会社コード / グループ会社名 | 代理店グループ（agency_groups.group_code に相当） |
| 代理店コード / 代理店名 | agencies.agency_code に相当 |
| ステータス | 商材ごとに値の定義が異なる可能性あり |
| お申込日 | |
| 最終更新日時 | |

**確認中事項**

| # | 確認事項 | 現状 |
|---|---|---|
| ① | 同一顧客が複数商材に登録されるケースの有無 | 確認中 |
| ② | 重複がある場合の表示方針（商材ごとに別行 / 名寄せして1行） | 未確定 |
| ③ | 商材間でステータスの統一定義が可能か | 未確定 |
| ④ | 各商材テーブルの顧客属性フィールドの差異（サンプルデータ待ち） | 未確定 |

---

### 4-1. 顧客一覧表示

| 項目 | 内容 |
|---|---|
| **項番** | 6 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |
| **対象テーブル** | `customers`（将来: 統合ビュー） |

**処理内容**

顧客情報を商材横断で一覧表示する。デフォルト並び順およびページネーションについては別途定義する。

**実装状況**

> ✅ **実装済み（R2）**: `Admin::CustomersController#index`（`policy_scope(Customer).order(:customer_number)` + pagy ページネーション。ビューは Hotwire+ERB `app/views/admin/customers/index.html.erb`）。CSV非同期エクスポート（`#export` → `CsvExport` + `CsvExportJob`。出力列は `CsvExportJob::EXPORT_TARGETS["Customer"]`、スコープは Pundit `policy_scope!` を通す）。
> ⚠️ **差分**: デフォルト並び順は `customer_number` 昇順で実装（別途定義予定だった項目。要件があれば変更）。

---

### 4-2. 検索・絞込

| 項目 | 内容 |
|---|---|
| **項番** | 7 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |
| **対象テーブル** | 各商材顧客テーブル（統合ビュー） |

**処理内容**

顧客一覧に対して以下の条件で検索・絞込を可能とする。

- フリー検索
- FTWEB顧客番号
- グループ会社コード / グループ会社名（代理店グループ）
- 代理店コード / 代理店名
- ステータス
- お申込日（期間指定）
- 最終更新日時（期間指定）

**実装状況**

> ⚠️ **差分（R2 実装は最小構成）**: 現状は `q` パラメータによる「顧客番号・氏名」の ILIKE 部分一致のみ。上記のうち FTWEB顧客番号（= `customer_number`）・顧客名はカバー済みだが、**代理店グループ / 代理店 / ステータス / お申込日期間 / 最終更新日時期間** の絞込は未実装。R6（運用強化）で `Admin::CustomersController#index` に条件を追加する（PostgreSQL + pg_bigm によるフリー検索の高速化も同時に検討）。要件自体は維持。

---

### 4-3. 権限制御

| 項目 | 内容 |
|---|---|
| **項番** | 8 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |
| **対象テーブル** | `customers` |

**処理内容**

ユーザー権限に応じて利用可能な画面、機能、操作、参照可能な顧客データを制御する（ロール権限）。

| ロール | 参照範囲 |
|---|---|
| 管理者 | 全顧客を参照可能 |
| 代理店営業担当者（代理店用アカウント） | `customers.agency_id` がログインユーザの `users.agency_id` と一致するレコードのみ参照可能 |
| 代理店グループ用アカウント | `customers.agency_id` → `agencies.agency_group_id` がログインユーザの `users.agency_group_id` と一致するレコードのみ参照可能 |

**補足**

権限種別は少なくとも以下を管理対象とする。

- 管理者
- BW作業者
- 代理店営業担当者

**実装状況**

> ✅ **実装済み（R2）**: 画面・操作の可否 = エンドポイントRBAC（`SystemPermission` × ロール）、参照可能データ = `CustomerPolicy`（`AgencyScoped`。`Scope#scope_for_agency` / `#scope_for_agency_group`）。`show` / `update` / `destroy` は `accessible?` で個別レコードも判定。CSVエクスポートも同じ `policy_scope!` を通す。
> ⚠️ **差分（呼称）**: 上記「権限種別」の BW作業者 = 組み込みロール `実務運用者`、代理店営業担当者 = `代理店用`（＋`代理店グループ用`）に対応。ロール名は 03§3「名称維持」の通り変更しない。なお「代理店営業担当者」（`SalesRepresentative`）自身は管理画面にログインしない（§1-1）ため、ここでの主体は「代理店用アカウント（User）」である。

---

## 5. 顧客詳細

> ✅ **フィールド定義は確定済み（Rails版 R2）**: 旧記述「フィールド定義待ち（未確定）」は、P2-4（Laravel側）で確定した `Column.md` §8（customers 拡張37カラム込みの完全版）に基づき、Rails版 R2 で `customers` テーブルとして実装済み。BridgePlus固有の受注・契約情報は `orders`（約90フィールド）・`order_work_details`（作業詳細。SNS認証情報等は `ActiveRecord::Encryption` で暗号化）・`stores` に分離して保持する。フィールド定義自体は `Column.md` を正とし、本書では再掲しない。

### 設計方針

- `customers` テーブルに顧客属性（BridgePlus固有フィールドを含む）を持つ（`app/models/customer.rb`）
- 受注・契約情報など関連テーブルから引き込む項目はリレーション定義済み: `Customer has_many :stores` / `has_many :orders`（`dependent: :restrict_with_error`。受注が残る顧客は物理削除不可）/ `belongs_to :agency` / `belongs_to :sales_representative`
- 表示項目・編集項目はユーザー権限（ロール）に応じて制御する（画面到達=エンドポイントRBAC、レコード=Pundit `CustomerPolicy`）
- ✅ PII 方針（Q-D）: 分類B（`order_work_details` の SNS/システム認証情報・`orders.billing_password`）は暗号化済み。分類A（顧客氏名・電話・メール等の `customers` 本体）は暗号化しない方針で実装が先行。**決定の文書化が未了**（04 R2見直し残タスク・`pii-handling-rules.md` へ反映要）

---

### 5-1. 顧客詳細表示

| 項目 | 内容 |
|---|---|
| **項番** | 9 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |
| **対象テーブル** | `customers`（関連テーブル `stores` / `orders` 含む） |

**処理内容**

登録済み顧客の詳細情報を表示する。画面上はタブで区分を分割して表示する。

表示可能項目はユーザー権限に応じて制御する。
- 管理者：全顧客の詳細情報を参照可能
- 代理店営業担当者（代理店用アカウント）：自代理店に紐づく顧客の詳細情報のみ参照可能

**実装状況**

> ✅ **実装済み（R2）**: `Admin::CustomersController#show`（`authorize @customer`）。店舗は `admin/customers/:customer_id/stores` にネスト（`Admin::StoresController`）。
> ⚠️ **差分**: 旧記述「タブで区分を分割」は現行 ERB 画面では単一ページ表示（タブ未実装）。表示フィールドは `Column.md` §8 全項目。タブ分割（基本情報 / 請求情報 / 担当者 / 店舗 / 受注 / 契約書）は R6 の UI 改善または R5 契約書参照（§14）追加時に Turbo Frame で実装する想定。業務上の優先度は要確認。

---

### 5-2. 顧客情報作成編集

| 項目 | 内容 |
|---|---|
| **項番** | 10 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / U |
| **出力** | 画面 / DB更新 |
| **対象テーブル** | `customers`（関連テーブル含む） |

**処理内容**

顧客情報の新規作成および編集を行う。

編集可能項目はユーザー権限に応じて制御する。
- 管理者：全顧客を編集可能
- 代理店営業担当者（代理店用アカウント）：自代理店に紐づく顧客のみ編集可能

**実装状況**

> ✅ **実装済み（R2）**: `Admin::CustomersController#new/#create/#edit/#update`（Strong Parameters で `Column.md` §8 全項目を許可。`status` は `customer_statuses.code` に存在する値のみ有効 = `Customer#status_must_exist_in_customer_statuses`）。所有権付け替え（`agency_id`）は `strip_ownership_params!` で代理店ユーザから遮断。変更差分は `Auditable::TRACKED_FIELDS["Customer"]`（name / status / agency_id / sales_representative_id / applied_at / contracted_at）を監査ログ記録。
> ⚠️ **差分**: 「代理店営業担当者が編集可能」は `CustomerPolicy#update?`（`accessible?`）で許可されるが、`create?` は `staff_scope?`（社内ユーザのみ）。代理店ユーザによる管理画面からの新規顧客作成は不可（新規顧客は申込フォーム経由で作成する前提）。業務要件と合致するか要確認。
> ⚠️ **差分（Q-B 呼称）**: `customer_statuses` の画面表記は「顧客ステータス」のまま。`status-naming-analysis.md` 案A（`customer_statuses` = 「申込ステータス」、`order_statuses` = 「案件ステータス」、R5 の契約ワークフロー = 「契約ステータス」）は `order_statuses` 側のみ適用済み。R5 着手前に統一する（04 R2 追加タスク）。

---

### 5-3. 顧客の利用停止

| 項目 | 内容 |
|---|---|
| **項番** | 11 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | U(D) |
| **出力** | 画面 / DB更新 |
| **対象テーブル** | `customers` |

**処理内容**

顧客の利用停止（退会）を行う。退会処理により顧客ステータスを退会済みに更新する。
退会済みの顧客は通常の一覧表示には含めず、検索条件により表示可能とする。

**実装状況**

> ✅ **実装済み（R2 一部）**: 退会済みステータス `CustomerStatus::CODE_WITHDRAWN`（`withdrawn`。`is_system=true` で削除不可）と `Customer.active` スコープ（退会済み除外）を実装。退会済み顧客はマイページにログインできない（`Customer#active_for_authentication?`）。
> ⚠️ **差分**: 専用の「利用停止」アクション（ボタン）は無く、編集画面で `status` を `withdrawn` に変更する運用。また `Admin::CustomersController#index` は `Customer.active` を既定適用しておらず、**退会済み顧客も一覧に表示される**（旧記述の「通常一覧には含めない」は未実装）。R6 の一覧検索強化（§4-2 差分）と同時に「既定=退会除外＋ステータス絞込で表示」へ揃える。
> ⚠️ **要確認**: 退会時に紐づく `orders` / `stores` / マイページアカウントをどう扱うか（受注ステータスの連動、店舗の `is_active=false`）は業務要件未定。R6 の CustomerStatus/OrderStatus 遷移バリデーション設計（04 R6）と併せて確定する。

---

## 6. 申込登録

### 6-1. 申込登録 / 顧客・受注・店舗情報登録

| 項目 | 内容 |
|---|---|
| **項番** | 12 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C |
| **出力** | 画面 / DB更新 |

**処理内容**

代理店営業担当者がログイン後、顧客にWeb画面で必要情報を入力させ、対象商品の購入申込を行う。
申込完了時に顧客情報、受注情報、店舗情報を登録し、申込元代理店および営業担当者をログイン情報から自動で紐づける。
顧客の手書き署名を必須で取得する（画像データ）。

> **署名取得条件：** 支払方法に関わらず、手書き署名は必須。（クレカ登録をはさむ違いあり）

**想定フロー**

```
営業担当者ログイン（代理店CD＋営業担当者CD＋メールOTP）        ✅ R3
  → 商品選択（Product。販売許可 Product.sellable_by で絞込）     ✅ R3
  → 顧客側が顧客情報を入力（FormTemplate 駆動の動的マルチステップ） ✅ R3
  → 申込完了（Customer + Store + Order + OrderWorkDetail 一括生成） ✅ R3
  → クレカ登録（ネットムーブ checkout リダイレクト）             ⏳ R5（§7）
  → 申込確認メール（確認書添付）                                  ⏳ R5（確認書PDF。現状は添付なしの完了メールのみ）
  → 重要事項説明チェック                                          ⏳ R5（P3-12/13。状態機械の後に着手）
  → 手書き署名（画像）                                            ⏳ R5
  → 契約確認メール（契約書添付）                                  ⏳ R5（§13）
```

**実装状況（Rails版）**

> ✅ **実装済み（R3）**: 申込フォーム基盤。
> - 認証: `Form::SessionsController`（代理店CD＋営業担当者CD）→ `Form::OtpsController`（メールOTP）→ `session[:form_sales_representative_id]`。`FormAuthenticatable` concern で保護（RBACはスキップ。03§8-2 方式b）
> - フォーム定義: `FormTemplate`（Product と 1:1）─ `FormStep` ─ `FormField`（`field_key` / `field_type` / `target_table` / `target_column` / `required` / `validation_rules`(jsonb) / `input_options`(jsonb) / `editable_by_tier`(array) / `lock_after_status`）。P2拡張後仕様（3次元編集権限・動的マッピング）を初期スキーマに採用（03§5）。フォームビルダーは `Admin::FormTemplatesController`（ネスト属性で一括編集）。`target_column` はホワイトリスト制（agency_id 等の内部管理カラム・SNS認証情報・業務ステータス列へのマッピングは不可。2026-08-17 是正）
> - 進行管理: `Application`（`token`（URL に埋め込むワンタイム識別子。64桁 unique）/ `current_step_number` / `form_data`(jsonb) / `status`（`in_progress` / `completed`）/ `agency_id` / `sales_representative_id` / `product_id` / 完了後に `customer_id` / `store_id` / `order_id`）。ルート: `form/applications/new` → `#create` → `form/applications/:token/steps/:n`（`#show_step` / `#update_step`）→ `form/applications/:token/complete`（`#complete` / `#submit`）
> - 動的バリデーション: `Form::DynamicFormValidator`（`FormField.validation_rules` から生成）
> - 申込完了トランザクション: `Form::ApplicationSubmissionService#call`（1トランザクションで `Customer` → `Store` → `Order`（`contract_condition` は代理店の有効バージョンを自動取得。無ければ失敗）→ `OrderWorkDetail` → 選択オプション `OrderOption` を生成し、`Application` を `completed` に更新。申込元代理店・営業担当者はセッションから自動紐づけ）。完了後は `Application#form_data` から機密情報を除去（2026-08-17 是正）。request spec でカバー（`spec/requests/form/*`）
> - 通知: `Form::ApplicationMailer#confirmation`（顧客宛。添付なし）+ `StaffNotificationMailer#new_application`（スタッフ宛）を `deliver_later`。アプリ内通知 `SystemNotification::TYPE_APPLICATION_COMPLETED`（R4）
> - 初期ステータス: `Customer.status = applied`（`CustomerStatus::CODE_APPLIED`）、`Order.status = 0:受注`（`OrderStatus::CODE_ORDERED`）。旧記述の「初期ステータス案：申込受付」に相当
>
> ⏳ **未実装（R5）**: クレカ登録（§7）／申込確認メールへの確認書PDF添付／重要事項説明チェック（P3-12/13）／手書き署名の取得・保存（Active Storage に画像として `Order` または契約書レコードへ添付。取得手段は未確定⑤）／契約確認メール（§13）。
> ✅ **決定済み（2026-08-19・v5。旧①）**: 営業担当者が入力して仮申込を作成→顧客にメールでリンク送付→顧客がそのリンクから申込を再開する**ハイブリッド方式**を採用。R3現状（営業担当者のセッション内で完結・顧客スマホへのURL送付経路なし）から、R5で `Application#token` を使った別セッション許可（＋有効期限管理）を追加実装する。
> ⚠️ **要確認（R3 精査）**: `form-template-mapping.md` §2 の BRIDGE_PLUS 向け個別フィールド155項目と、実装済み FormField 定義（seed）との突合は未実施（04 R3 要確認）。

**疑問・未定義事項**

> - ★顧客重複問題：既存顧客と同じだった場合どうするか？
> - 初期ステータス案：申込受付
> - ★月額料金等はお客さんに見えないよう事前入力しておくか？（選択後のフロー）
> - ★重要事項の説明チェックあり

**確認中・未確定事項**

| # | 確認事項 | 現状 |
|---|---|---|
| ① | 顧客の情報入力端末・環境（営業担当者端末を渡す / 顧客スマホにURL送付 / 両対応） | ✅ 決定済み（2026-08-19・v5）: 営業担当者入力→仮申込→顧客へメールでリンク送付→顧客が続きを入力するハイブリッド方式 |
| ② | 支払方法の種類（クレカのみ / 口座振替等も対応） | 未確定（Q-26は「信販は対象外」と決定済み。クレカ以外の既存選択肢の扱いは引き続き未確定） |
| ③ | 顧客重複時の対応方針（エラー停止 / 警告して続行 / 既存顧客に自動紐づけ） | 未確定 |
| ④ | 重要事項説明チェックの実施者・タイミング（顧客がWeb上でチェック / 営業担当者が口頭説明後に記録） | 未確定（04 Q-35・`contract-confirmation-docs.md` Q-1〜9） |
| ⑤ | 手書き署名の取得手段（タブレット上で描画 / 紙をカメラ撮影してアップロード） | 未確定（04 Q-35） |

> ③ 顧客重複問題は R6 の名寄せ（`customer-merge-design.md`）と関連。R3 実装は「常に新規 Customer を作成」（重複検知なし）。①は2026-08-19に決定済み。②〜⑤はR5着手前に確定すること（04 R5着手前チェックリストと併読）。

---

## 7. 決済連携

### 7-1. クレカ情報の外部連携

| 項目 | 内容 |
|---|---|
| **項番** | 13 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C |
| **出力** | 画面 / DB更新 |

**処理内容**

クレカ情報を入力時にクレカ情報の有効性チェックを行い、外部連携APIにて登録する。

> **参照ドキュメント：** `Z:\05.システム企画\04.案件\13.ジャスミンCRM改修\C.外部決済(クレカ有効性)`

**実装状況・Rails版実装方針**

> ⏳ **未実装（R5。Laravel版でも未実装 → Rails版で新規設計実装）**。04 R5「PaymentTransaction 状態機械の忠実移植 + ネットムーブ連携」。現行スキーマには決済用の記録列（`orders.payment_method` / `payment_collected_at` / `payment_doc_confirmed_at` / `finance_*`（信販9カラム）、`customers.netmove_member_id` / `netmove_registered_at`）のみ存在し、`payment_transactions` / `payment_transaction_logs` は未作成。
>
> **Rails版実装方針（`payment-integration.md` §4〜§6 に整合）**
> - モデル: `PaymentTransaction`（`order_id` FK / `customer_id` / `kind`(与信・売上・カード登録) / `amount` / `status` / `netmove_transaction_id` / `jutyu_cd` / `authorized_at` / `captured_at` / `failed_at` / `idempotency_key`）+ `PaymentTransactionLog`（送受信ペイロード・署名検証結果・IP を全件記録。§4-5）。テーブル名・列は `payment-integration.md` §5 を正とし、`Column.md` に追記する
> - 状態機械: `pending / authorized / captured / failed / unknown / canceled / refunded`（§4-4）を **gem を使わず手実装**（03§2「unknown 系の特殊遷移が歪むなら AASM 等は使わない」）。`unknown`（応答なし・タイムアウト）を `failed` に丸めない。`mark_*`（自社側の遷移要求）と `confirm_*`（サーバ間照会・突合で確定）を分離。遷移表は model spec で固定する（04「リスク2」）
> - 冪等性・二重課金防止（§4-2）: `idempotency_key` unique + `Order` 行ロック（`with_lock`）で同一受注の同時決済開始を直列化。**決済ジョブは Solid Queue の専用キュー（例 `payments`）に載せ、自動リトライを無効化**（`retry_on` を付けない／`discard_on` 明示。04 R5「デフォルト再試行のまま流すと二重課金を自動で起こす」）
> - 連携方式: ネットムーブ checkout（リダイレクト型・HMAC-SHA256 署名・カード情報非保持非通過）。`ret_url` 受け口は `form` 名前空間のコントローラ（例 `Form::PaymentCallbacksController`）で、**ログインセッションに依存せず** `PaymentTransaction` を DB から復元し、金額は DB 値と突合、`check_cd` 署名検証と結果コードの両方が揃わなければ `unknown` 留置（§4-9）。`cancel_url` は無署名のため状態遷移の根拠にしない
> - 突合: `ReconciliationSource` インターフェース（照会API / Webhook / 取引履歴CSV のいずれか。Q-38 の確定待ち）を rake タスク / Solid Queue recurring で日次実行
> - 決済状態と案件ステータス（`orders.status`）は分離し、連動ルール（§4-6）は R5 の契約ワークフロー状態機械側で定義
> - 3Dセキュア項目（§4-7）・与信/売上の分離（§4-8）・会員ID引き継ぎ（`netmove-card-migration.md`。会員ID採番の新旧連続・`member-modify` 導線・R7 ETL 枠）を R5 本文に含める
> - 決済専用の監査ログ: `AuditLog` とは別に `PaymentTransactionLog` を保持し、`Auditable::TRACKED_FIELDS["PaymentTransaction"]` にも status 遷移を登録
> - **決済状態機械の request spec は必須**（04 R5・`payment-integration.md` §6「省略しない」）
> - 請求用受注データCSV出力（D-P8。継続課金の売上処理は TBSS スコープ外）は `CsvExportJob::EXPORT_TARGETS` の拡張として R5 か R6（P4-12 プロファイル汎用化）のどちらで実装するかを R5 着手時に確定

**確認中・未確定事項**

> **⚠️ 本章の決済詳細は古い（2026-07-27）**
> APIドキュメントは受領済みで、最新の正は `payment-integration.md`、`legacy-research/02-payment-netmove.md`、`netmove-card-migration.md` とする（旧参照の `impl-plans/P3-2-payment.md` は削除済み・旧Laravel側に残存。Rails版の実装計画は `04-rails-implementation-plan.md` R5 が代替）。本章は基本要件の出典として残し、実装判断は上記文書と `development-plan.md` P3-2（= R5）を参照する。
> R5 着手前ブロッカー: Q-25（返金・キャンセル）/ Q-26（信販）/ Q-27（決済障害時縮退運用）/ Q-36（決済トランザクション紐づけ単位）/ Q-37（jutyu_cd 桁数）/ Q-38（決済結果確定手段）/ Q-39（ステージング検証方式）、通知マトリクス E6（決済失敗の通知先）。

| # | 確認事項 | 現状 |
|---|---|---|
| ① | 利用する外部決済サービス名・API種別 | ✅ ネットムーブ checkout（リダイレクト型） |
| ② | クレカ有効性チェックのタイミング | ✅ checkoutによるカード登録・1円与信を第1段で実装 |
| ③ | クレカ情報のDB保存方針 | ✅ 自社非保持。会員ID・下4桁等の表示/突合情報のみ保持 |
| ④ | 決済失敗時・API連携エラー時のハンドリング方針 | 未確定。unknownをfailedに丸めず、確定手段（照会API/Webhook/取引履歴CSV）はQ-38 |
| ⑤ | 口座振替など他の支払方法がある場合の連携方針（6章②と連動） | 未確定（Q-7）。おまとめ請求は申込時・契約後スタッフ設定の両対応方針 |

---

## 8. 入力チェック設定

### 8-1. 入力チェック設定 / 誤入力検知ルール管理

| 項目 | 内容 |
|---|---|
| **項番** | 14 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

各工程における誤入力検知ルールを、管理者が登録・参照・編集・無効化できるようにする。

**ルールに設定可能な項目**

| 設定項目 | 内容 |
|---|---|
| 対象工程 | 申込登録、顧客編集等 |
| 対象項目 | - |
| 入力チェック条件 | - |
| 警告文言 | - |
| 適用開始日 | - |
| 有効/無効状態 | - |

**確認中・未確定事項**

| # | 確認事項 | 現状 |
|---|---|---|
| ① | チェック動作の種別（警告表示のみで続行可能 / エラーで続行不可 / ルールごとに設定） | 未確定 |
| ② | 入力チェック条件の種類（正規表現 / 値の範囲 / 他項目との組み合わせ条件 / その他） | 未確定 |
| ③ | 対象工程の拡張予定（申込登録・顧客編集以外にも増える想定があるか） | 未確定 |
| ④ | コード側の固定バリデーションと本ルール管理（動的バリデーション）の役割分担 | 未確定 |

**実装状況・Rails版実装方針**

> ⏳ **未実装（R5「入力チェック設定（3段階必須）」）**。
> ✅ 関連実装済み（R3）: 申込フォームの項目単位バリデーションは `FormField.required` / `validation_rules`(jsonb) → `Form::DynamicFormValidator` で動的生成しており、④の「動的バリデーション」の一部（フォーム定義に属する形式チェック）は既に FormField 側にある。
> **Rails版実装方針**:
> - 本章の「誤入力検知ルール」は FormField とは別に、工程横断の業務ルールとして `InputCheckRule` モデル（`target_process`（申込登録 / 顧客編集 / 不備チェック…）/ `target_table` / `target_column` / `condition_type`（regex / range / cross_field / custom）/ `condition`(jsonb) / `severity`（warning: 続行可 / error: 続行不可。①の答えを「ルールごとに設定」で持てる構造）/ `message` / `effective_from` / `is_active`）として管理画面 CRUD（`Admin::InputCheckRulesController`。admin ロールのみ）で扱う案
> - 評価は `InputCheckRuleEvaluator` サービスに集約し、申込フォーム（`Form::ApplicationsController#update_step`）と管理画面の顧客/案件編集（`Admin::CustomersController#update` 等）から共通に呼ぶ。warning は Turbo Stream で画面に警告表示して続行可、error は `errors.add` で保存拒否
> - 「3段階必須」（R5）= 必須 / 推奨（warning）/ 任意 の区分は `FormField.required` の拡張（`requirement_level`）か `InputCheckRule.severity` のどちらで持つかを R5 設計時に決める
> - ①〜④の未確定事項は R5 着手前に業務側で確定する

---

## 9. 不備チェック

### 9-1. 契約情報不備チェック

| 項目 | 内容 |
|---|---|
| **項番** | 15 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

管理者が契約情報を参照し、チェック項目に従って内容確認を行う。
問題がない場合は次工程へ進め、問題がある場合は差戻し可能とする。

**ステータス管理**

| ステータス |
|---|
| 差戻し |
| 確認コール待ち |
| 契約確定待ち |

**疑問・未定義事項**

> - ★不備チェックをなくせないか？
> - ⇒WEB上で口振工数

**実装状況・Rails版実装方針（§9〜§12 共通: 契約ワークフロー状態機械）**

> ⏳ **未実装（R5「契約ワークフロー状態機械（不備チェック→差戻し→確認コール→契約確定）」）**。
> ✅ 関連実装済み: `orders.contract_status`（string(10)。現状は自由入力の記録列。`Auditable::TRACKED_FIELDS["Order"]` に含む）、確認コール記録列 `orders.confirm_call_*`（§12）、`orders.contract_start_date` / `contract_sent_at`。問い合わせカテゴリ「後確」（`Inquiry::CATEGORY_POST_CONFIRM`。R4）は確認コール後のフォロー用途で本ワークフローとは別物。
> **Rails版実装方針**:
> - §9〜§12 に散在するステータス（差戻し / 確認コール待ち / 契約確定待ち / 差戻し中 / 再申請待ち / 再チェック待ち / 確認コール済 / 再確認要 / 契約確定）を **1本の「契約ステータス」**（Q-B 案A の第3の語。`status-naming-analysis.md`）として統合し、`orders.contract_status` を状態機械の状態列として使う（列幅 10 は拡張。または `contract_workflow_states` マスタ + `orders.contract_status` code 参照の `CustomerStatus` / `OrderStatus` と同型構成）。案件ステータス（`orders.status`）・申込ステータス（`customers.status`）とは分離し、連動ルールを明示する
> - 状態機械は決済（§7）と同じく **手実装**（`Order#transition_contract_to!(event)` + 遷移表を定数で宣言 + model spec で遷移表を固定）。不正遷移は例外
> - 遷移履歴・差戻し内容は別テーブル `contract_reviews`（`order_id` / `event`（check_passed / returned / call_done / confirmed …）/ `from_status` / `to_status` / `reason` / `target_fields`(jsonb) / `comment` / `performed_by`（User）/ `performed_at`）で保持し、監査ログ（`AuditLog`）にも記録
> - 管理画面: `Admin::OrdersController#show` に契約ワークフロー操作（Turbo Frame）を追加、または `Admin::ContractReviewsController`（`create` = 遷移イベント投入）を分離。操作可否はエンドポイントRBAC、対象案件は Pundit `OrderPolicy`
> - **実装順（04 R5・`contract-confirmation-docs.md`）**: 状態機械の設計を先に固めてから重説チェック（P3-12/13）へ着手する（先に重説を単独実装すると「重説未実施の案件を不備チェックへ進めてよいか」で手戻る）
> - 差戻し後の修正主体（営業担当者 / 顧客）に応じて、`FormField.editable_by_tier` / `lock_after_status`（R3 実装済み）で編集可否を制御し、`Application#token` 付き URL を再送して再入力させる
> - 遅延検知・自動キャンセル（R6）と通知マトリクス E8（自動キャンセル時に顧客へ通知するか）はこの状態機械のイベントをフックする

---

## 10. 差戻し

### 10-1. 契約情報差戻し

| 項目 | 内容 |
|---|---|
| **項番** | 16 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | U |
| **出力** | 画面 / DB更新 |

**処理内容**

管理者が差戻し対象項目および差戻し理由を登録し、差戻し先を明確化したうえで差戻しを行う。
差戻し後は、代理店営業担当者または顧客が修正可能とし、修正後は再度チェック待ちに戻す。

**入力項目**

| 入力項目 |
|---|
| 差戻し理由 |
| 差戻し対象項目 |
| 修正依頼コメント |

**ステータス管理**

| ステータス |
|---|
| 差戻し中 |
| 再申請待ち |
| 再チェック待ち |

**実装状況**

> ⏳ **未実装（R5）**。実装方針は §9 の「契約ワークフロー状態機械」に統合（差戻し理由・対象項目・修正依頼コメントは `contract_reviews` レコードとして保持。差戻し先（営業担当者 / 顧客）は `returned_to` 列で明示し、通知は `RecipientResolver` + `NotificationTemplate`（R4 実装済み）経由でメール送付）。

---

## 11. キーワード選定

### 11-1. キーワード自動選定

| 項目 | 内容 |
|---|---|
| **項番** | 17 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | U |
| **出力** | 画面 / DB更新 |

**処理内容**

申込登録 / 顧客・受注・店舗情報登録時に選定するキーワードをおすすめで自動選択できるようにする。

**疑問・未定義事項**

> - ★キーワードチェックをなくせないか？
> - ⇒メインキーワードとサブキーワード4つをおすすめ自動設定できないか？

**実装状況・Rails版実装方針**

> ⏳ **未実装（R5。P3-11。2026-08-15 に計画へ復元）**。
> ✅ 関連実装済み（R2）: 保存先カラムは `order_work_details.keyword_industry_main` / `keyword_industry_sub1`〜`sub4` / `keyword_area_1`〜`3` / `keyword_prefecture` / `keyword_city` / `keyword_region_industry` / `industry_keyword` / `business_category_keyword` / `keyword_remarks`（「メイン1＋サブ4」の器は既にある）。
> **Rails版実装方針**: `KeywordSuggestionService`（入力: 業種（`customers.industry` / `industry_sub` = OptionValue ツリー）・所在地（都道府県/市区）・店舗名。出力: メイン1＋サブ4の候補）を用意し、申込フォームの該当ステップ（`Form::ApplicationsController#show_step`）で Stimulus コントローラから候補を取得して初期値に自動セット、営業担当者が上書き可能とする。候補ロジック（辞書 vs 外部API vs 過去受注統計）は R5 設計時に業務側と確定。「キーワードチェックをなくせないか」の判断は業務側未決。

---

## 12. 確認コール

### 12-1. 確認コール

| 項目 | 内容 |
|---|---|
| **項番** | 18 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

管理者が顧客に確認コール対象契約を抽出し、確認コール結果を記録する。
結果に応じて契約確定または再差戻しの判断を行う。

**ステータス管理**

| ステータス |
|---|
| 確認コール待ち |
| 確認コール済 |
| 再確認要 |
| 契約確定 |

**疑問・未定義事項**

> - ★確認コール後、契約開始日が契約書に記載される

**実装状況**

> ⏳ **未実装（R5）**。状態遷移は §9 の契約ワークフロー状態機械に統合。
> ✅ 関連実装済み（R2）: 記録列 `orders.confirm_call_contact_name` / `confirm_call_preferred_date` / `confirm_call_time` / `confirm_call_staff_name` / `confirm_call_notes` / `confirm_call_remarks`、契約開始日 `orders.contract_start_date`（確認コール後に確定 → §13 契約書へ印字）。「確認コール対象契約の抽出」は `Admin::OrdersController#index` の契約ステータス絞込（R5 で追加）で行う。
> ⚠️ 通知マトリクス（`notification-matrix.md`）の確認コール関連イベント（E-系）の受信者ルールは「?要確認」のまま。R5 着手前に確定。

---

## 13. 契約書作成

### 13-1. 契約書作成

| 項目 | 内容 |
|---|---|
| **項番** | 19 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C |
| **出力** | 画面 / DB更新 |

**処理内容**

契約確定済みの契約情報を対象として契約書データを生成する。
必要に応じてPDF化し、作成版数または最新版を管理可能とする。

**疑問・未定義事項**

> - ★契約書をシステムからメール送付する

**実装状況・Rails版実装方針**

> ⏳ **未実装（R5「契約書PDF生成・版数管理・メール送付、手書き署名」）**。
> **Rails版実装方針**:
> - PDF 生成ライブラリは **要選定（03§2: grover / ferrum 系（HTML→PDF。ERB テンプレートを流用できる）or prawn（Ruby ネイティブ。日本語フォント同梱要））**。R5 着手時に決定。契約書レイアウトが HTML/CSS で表現しやすい（表・章立て中心）なら前者を優先
> - モデル: `ContractDocument`（`order_id` FK / `version`（連番。同一 order 内 unique）/ `document_type`（契約書 / 確認書 / 重説）/ `generated_at` / `generated_by` / `sent_at` / `is_latest`）+ Active Storage `has_one_attached :pdf`。生成時点のスナップショット（顧客名・プラン・料金・契約開始日・営業担当者の `pdf_*` 印字用住所（§3-1 ⑤））を `snapshot`(jsonb) に保持し、マスタ変更の影響を受けない（§18-3 と同じ思想）
> - 生成は Solid Queue ジョブ（`ContractDocumentGenerateJob`）で非同期。完了でアプリ内通知（`SystemNotification`）
> - メール送付は `ContractMailer#deliver_contract`（`deliver_later`。PDF 添付）。送付先は顧客メール + 代理店通知先（`agencies.email_1〜5`）。テンプレートは `NotificationTemplate`（R4）を流用
> - 手書き署名は Active Storage（`has_one_attached :signature_image` を `Order` または `ContractDocument` に）。取得手段（§6 ⑤）と法的要件（電子契約フラグ `agencies.electronic_contract_enabled` の意味付け）は R5 着手前に確定
> - 版数管理: 再生成のたびに `version` をインクリメントし旧版は保持（削除しない）。「最新版」= `is_latest=true`
> - 監査: 生成・送付・再生成を `AuditLog` に記録（§16-1「契約書作成」）

---

## 14. 契約書参照

### 14-1. 契約書参照

| 項目 | 内容 |
|---|---|
| **項番** | 20 |
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 / DB更新 |

**処理内容**

- 顧客詳細ページから契約書一覧または最新契約書を表示する。
- 受注詳細ページから該当受注に紐づく契約書を表示可能とする。
- 必要に応じてダウンロード可能とする。

**実装状況・Rails版実装方針**

> ⏳ **未実装（R5）**。§13 の `ContractDocument` を前提に、`Admin::CustomersController#show`（顧客配下の全受注の契約書一覧）と `Admin::OrdersController#show`（該当受注の契約書）に Turbo Frame で一覧を追加し、ダウンロードは Active Storage の署名付き URL（`rails_blob_path`。有効期限付き）で提供。参照可否は Pundit（`OrderPolicy` を継承した `ContractDocumentPolicy`。代理店=自代理店のみ）+ エンドポイントRBAC。
> ⚠️ 顧客マイページ（`Mypage::DashboardController`。R4 は受注一覧20件の最小構成）からの契約書参照・ダウンロードは要件未定。必要なら R5/R6 で `mypage` section にルートを追加する（要確認）。

---

## 15. 案件一覧（Bridge管理 / BridgePlus管理）

### 15-1. 案件検索（メールアドレス条件追加）

| 項目 | 内容 |
|---|---|
| **項番** | 25 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |

**処理内容**

案件一覧・検索画面に顧客メールアドレスの検索条件を追加し、案件（契約内容）に紐づく顧客メールアドレスによる検索を可能とする。

**実装状況**

> ✅ **実装済み（R2）**: 案件一覧 `Admin::OrdersController#index`（`policy_scope(Order)` + pagy。CSV非同期エクスポート `#export`）。旧「Bridge管理 / BridgePlus管理」の2画面は、Rails版では **単一の案件一覧**（`orders`）で扱い、サービス区分は `agency_groups.service_type` / `products` で判別する（決定D。テーブル分離しない）。
> ⚠️ **差分**: 現状の検索条件は `q`（案件番号 `order_number` の ILIKE）と `status`（案件ステータス）のみ。**顧客メールアドレス（`customers.email` を JOIN）による検索は未実装**。R6 の一覧検索強化（§4-2 と同時）で追加。要件維持。

---

### 15-2. 案件編集

| 項目 | 内容 |
|---|---|
| **項番** | 26 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | U |
| **出力** | 画面 / DB更新 |

**処理内容**

案件ごとの編集機能。案件自体は「申込登録 / 顧客・受注・店舗情報登録」時に自動作成される。

**実装状況**

> ✅ **実装済み（R2/R3）**: `Admin::OrdersController#edit/#update`（`Column.md` §9 の約90フィールドを Strong Parameters で許可。`status` は `order_statuses.code` に存在する値のみ = `Order#status_must_exist_in_order_statuses`。`agency_id` / `customer_id` / `store_id` の付け替えは `strip_ownership_params!` で遮断）。案件の自動作成は `Form::ApplicationSubmissionService`（§6）。案件番号 `order_number`（`ORD{年}{連番}`）は `SequenceCounter` で採番。
> ⚠️ **差分**: 案件の新規手動作成（`#new/#create`）も管理画面に存在する（社内ユーザのみ。旧記述の「自動作成のみ」より広い）。手動作成の業務利用可否は要確認。
> ⏳ **未実装（R6）**: CustomerStatus / OrderStatus の遷移バリデーション（不正遷移防止）。現状はマスタに存在するコードかのみ検証。

---

## 16. 監査ログ

### 16-1. 操作履歴記録

| 項目 | 内容 |
|---|---|
| **項番** | 32 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R |
| **出力** | 画面 / DB更新 |

**処理内容**

ログインユーザによる主要操作の履歴を記録する。

**記録対象操作**

| 操作種別 |
|---|
| ログイン |
| ログアウト |
| 顧客編集 |
| 契約情報更新 |
| 差戻し |
| 確認コール |
| 契約書作成 |

**実装状況**

> ✅ **実装済み（R0）**: ftlog の監査ログ一式を移植（spatie/activitylog 相当）。`AuditLog`（`user_type` / `user_id`（User / Customer / SalesRepresentative）/ `action` / `resource_type` / `resource_id` / `resource_label` / `changes_before` / `changes_after`(jsonb) / `metadata` / `ip_address` / `request_id` / `source`）。
> - モデル変更: `Auditable` concern（`after_create/update/destroy`）。記録対象カラムは `Auditable::TRACKED_FIELDS` にモデル別ホワイトリストとして宣言（User / SystemRole / IpAllowlistEntry / AgencyGroup / Agency / SalesRepresentative / ContractCondition / Customer / Store / Order / Product / Plan / … / Inquiry / Notification 等 30 モデル超）。`Current.request_id` / `Current.ip_address` を自動付与
> - 認証イベント: `AuthAuditable` concern（`login_succeeded` / `login_failed` / `account_locked` / `password_reset_*` / `otp_issued` / `otp_verified` / `otp_failed` / `permission_denied`）。User / Customer の双方に include。権限拒否（403）も記録（R0 完了条件）
> - 上表のうち「ログイン」「顧客編集」「契約情報更新（= Order の TRACKED_FIELDS）」は実装済み。「差戻し」「確認コール」「契約書作成」は R5 の該当機能実装時に `TRACKED_FIELDS`（`ContractReview` / `ContractDocument`）へ追加
> ⚠️ **差分**: 「ログアウト」イベントは `AUTH_ACTIONS` に含まれていない（未記録）。R6 で `logout` アクションを追加する（要件維持）。営業担当者（form）は `AuthAuditable` を include せず、OTP イベント（`otp_issued` / `otp_verified` / `otp_failed`）のみ `SalesRepresentative#after_otp_event` で記録し、申込完了は `Form::ApplicationsController` が `application_completed` を明示記録する（`Current.user` は form 文脈で nil のため `Auditable` 自動フックには乗らない）。代理店CD＋営業担当者CD の照合失敗（`login_failed` 相当）は未記録 → R8 のセキュリティ確認で追加を検討。
> - 保存期間: 5年（development-plan Q-22）。自動 prune は未実装（R8 運用設計で確定）

---

### 16-2. 操作履歴参照

| 項目 | 内容 |
|---|---|
| **項番** | 33 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |

**処理内容**

管理者が操作履歴を一覧表示し、以下の条件で検索・参照可能とする。

- ユーザ
- 操作種別
- 対象データ
- 実行日時

**実装状況**

> ✅ **実装済み（R0 一部）**: ログイン履歴画面 `Admin::LoginHistoriesController#index`（`AuditLog.auth_events.recent.limit(200)`。専用の `login_histories` テーブルは持たず AuditLog の絞込ビュー。admin ロールのみ）。
> ⚠️ **差分**: **汎用の操作履歴検索画面（ユーザ / 操作種別 / 対象データ / 実行日時で絞込）は未実装**。現状は認証イベント直近200件の固定表示のみ。R6 で `Admin::AuditLogsController#index`（pagy + 上記4条件）を追加する（要件維持）。

---

## 17. 問い合わせ管理

### 17-1. 問い合わせフォーム

| 項目 | 内容 |
|---|---|
| **項番** | 61 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | C |
| **出力** | 画面 |

**処理内容**

フォーム画面から問合せを行う。顧客側のメールアドレス等にて顧客情報の紐づけを行い、対象の代理店のみ問合せ内容を参照可能とする。

返信内容はシステム側で送付し、顧客は受信したメールアドレスに記載のリンクから追加返答等を行い、システム側で問合せ履歴を管理する。

> 別途、問合せ一覧から手動での新規作成も可能とする。

**実装状況**

> ✅ **実装済み（R4）**: 問い合わせ基盤。`Inquiry`（`inquiry_number`（`INQ-000001`。`SequenceCounter` 採番）/ `order_id`（案件に紐づく）/ `category`（掲示板4種統合。決定D-11・`board-implementation-options.md`: `後確` / `制作対応` / `検収コール` / `アフター問合せ`）/ `status`（`inquiry_statuses` マスタ参照。enum 撤廃）/ `title` / `is_visible_to_agent` / アフター固有列 `after_urgency` / `after_type` / `after_area` / `reception_channel` / `first_responder_name` / `next_responder_name`）─ `InquiryMessage`（本文 + Active Storage 添付。合計サイズ検証あり）─ `InquiryMessageRecipient`（宛先解決結果）。
> - 宛先解決: `RecipientResolver`（種別×ステータス → `InquiryRecipientRoute` → `RecipientGroup` / `RecipientGroupMember`）。メール送信は `InquiryMessageMailJob` → `InquiryMailer#message_notification`（`deliver_later`）。アプリ内通知は `InquiryNotifier` → `SystemNotification`（`inquiry_created` / `inquiry_replied`。Solid Cable でリアルタイム配信、30日で prune）
> - 手動新規作成: `Admin::InquiriesController#new/#create`（一覧から。旧記述の「別途、手動作成」に該当）
> ⚠️ **差分 / 未実装**: **顧客側の公開問い合わせフォーム**（メールアドレスで顧客を紐づけ）と、**顧客がメール記載リンクから追加返答する経路**は未実装。R4 の Inquiry は管理画面（社内・代理店）起点で、顧客への送信は片方向メール。顧客からの返信受付は マイページ（`mypage` section）にスレッド表示・返信フォームを追加する形で R6 に実装する想定（`Customer` は Devise + OTP でログイン可能なので、メールリンク → マイページログイン → 返信、が自然）。要件維持。
> ⚠️ **差分**: 「対象の代理店のみ問合せ内容を参照可能」は `InquiryPolicy`（Order 経由の `AgencyScoped`）+ `is_visible_to_agent` フラグで実装。

---

### 17-2. 問い合わせ検索

| 項目 | 内容 |
|---|---|
| **項番** | 61 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | R |
| **出力** | 画面 |

**処理内容**

問い合わせ一覧・検索画面にて問い合わせ検索を可能とする。

**実装状況**

> ✅ **実装済み（R4）**: `Admin::InquiriesController#index`（`policy_scope(Inquiry)` + pagy。`category` 絞込）。
> ⚠️ **差分**: 検索条件は `category` のみ。ステータス / 案件番号 / 顧客名 / 期間 / 担当者での絞込は未実装（R6 の一覧検索強化で追加）。

---

### 17-3. 問い合わせ登録・対応記録

| 項目 | 内容 |
|---|---|
| **項番** | 62 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U |
| **出力** | 画面 / DB更新 |

**処理内容**

顧客⇔弊社間の問い合わせ対応履歴を管理する。

**実装状況**

> ✅ **実装済み（R4）**: `Admin::InquiriesController#show`（スレッド表示）+ `Admin::InquiryMessagesController#create`（返信投稿。同時にステータス更新可・添付可・宛先解決・メール送信・アプリ内通知）。ステータスマスタ `InquiryStatus`（種別ごと。`is_system` 行は削除不可）は `Admin::InquiryStatusesController`、ルーティングマスタは `Admin::InquiryRecipientRoutesController`。変更は `Auditable::TRACKED_FIELDS["Inquiry"]`（category / status / order_id / is_visible_to_agent）で監査。
> ⚠️ **差分**: Inquiry の編集（`edit/update`）・削除ルートは意図的に無い（履歴改ざん防止。ステータス変更はメッセージ投稿と同時のみ）。業務上、タイトル等の訂正 UI が必要かは要確認。

---

### 17-4. 問い合わせテンプレート管理

| 項目 | 内容 |
|---|---|
| **項番** | 63 |
| **必須** | - |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U / D |
| **出力** | 画面 / DB更新 |

**処理内容**

返信用の問合せテンプレートを管理する。

**実装状況**

> ⚠️ **差分 / 未実装（R4 後続 or R6 or R7。フェーズ未確定）**: R4 の `NotificationTemplate`（`template_type`: `notification`（通知用）/ `inquiry`（問い合わせ用）/ `common`（共通）。`Admin::NotificationTemplatesController` CRUD）に **「問い合わせ用」区分は存在する**が、`Admin::InquiryMessagesController` から未参照で、返信画面でのテンプレ選択 UI・差し込み変数の展開・FAQ 12 カテゴリのマスタ（`legacy-research/13-faq-templates.md`）は未実装（04 R4 未実装ギャップ）。
> **Rails版実装方針**: `NotificationTemplate`（inquiry 区分）に `category`（FAQ カテゴリ）列を追加し、`Admin::InquiryMessagesController` の返信フォームに Stimulus でテンプレ選択 → 本文差し込み（変数展開は `Mustache` 風の `{{customer_name}}` 等をサーバ側で `NotificationTemplate#render(context)`）を追加。FAQ 318 件の実データ投入は R7 のデータ投入と連動。**実装要否とフェーズは CEO・業務側の確認事項**（04 次のアクション 5）。

---

---

## 18. 選択肢マスタ管理

### 概要

申込登録・契約時に使用する選択肢（業種・支払方法等）を管理者が一元管理する画面。選択肢は階層構造を持ち、有効/無効の切り替えが可能。操作は管理者のみ。

> ✅ **実装済み（R2）**: `OptionGroup` / `OptionValue`（`Admin::OptionGroupsController` / `Admin::OptionValuesController`）。ツリーは **`parent_id` 方式（自己参照 + `depth`）**で実装（03§2 の closure_tree / ancestry 案は採用せず gem 追加なし。`app/models/option_value.rb`）。操作権限はエンドポイントRBAC（既定マトリクスで社内ロールに割当。「管理者のみ」に絞る場合は権限マトリクス画面で調整）。

---

### 18-1. 値グループ管理

| 項目 | 内容 |
|---|---|
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U |
| **出力** | 画面 / DB更新 |
| **操作権限** | 管理者のみ |

**処理内容**

選択肢のグループ（カテゴリ）を管理する。グループはコード側から参照するためのシステムキーを持つ。

**管理項目**

| 項目 | 内容 |
|---|---|
| グループ名 | 表示名（例：業種、支払方法） |
| システムキー | コードから参照するための固定キー（例：`industry_type`）。作成後は変更不可 |
| 説明 | グループの用途説明（任意） |
| 有効/無効 | 無効にすると配下の全選択肢も非表示になる |
| 表示順 | 管理画面上の並び順 |

> ✅ **実装済み（R2）**: `option_groups.key`（unique・作成後変更不可）/ `label` / `description` / `sort_order` / `is_active`。監査 `TRACKED_FIELDS["OptionGroup"]`（key / label / is_active）。
> ⚠️ **差分**: 「無効にすると配下の全選択肢も非表示」は、参照側で `OptionGroup.active` と `OptionValue.active` の両方を見る前提。フォーム側（`FormField.input_options` からの選択肢参照）で group の `is_active` を見ているかは R3 実装の確認事項（R5 の入力チェック設定と併せて点検）。

---

### 18-2. 値（選択肢）管理

| 項目 | 内容 |
|---|---|
| **必須** | 〇 |
| **操作手段** | 画面表示 |
| **CRUD/B** | C / R / U |
| **出力** | 画面 / DB更新 |
| **操作権限** | 管理者のみ |

**処理内容**

グループに属する選択肢を管理する。選択肢は階層構造（親子関係）を持ち、表示順の変更・有効/無効の切り替えが可能。

**管理項目**

| 項目 | 内容 |
|---|---|
| 表示名（ラベル） | 画面に表示する名称（例：飲食業） |
| 内部値 | DBに保存するコード（例：`food`） |
| 親選択肢 | 階層構造の親となる選択肢（ルートの場合はなし） |
| 表示順 | 同一階層内での並び順 |
| 有効/無効 | 無効にすると新規の申込画面に表示されなくなる |

**階層構造のイメージ**

```
業種（グループ）
  ├── 飲食業（大分類）
  │     ├── ラーメン（中分類）
  │     └── 寿司（中分類）
  ├── エステ（大分類）
  └── 宿泊（大分類）
```

> ✅ **実装済み（R2）**: `OptionValue`（`value`（グループ内 unique）/ `label` / `parent_id` / `depth`（親から自動算出）/ `sort_order` / `is_active`）。**同一グループ内のみ親に指定可**（`parent_must_be_same_option_group`）・**循環参照防止**（`parent_must_not_create_cycle`。2026-08-17 是正）。子は `dependent: :destroy`。

---

### 18-3. 旧名称の保持ルール

選択肢の表示名を変更・無効化した場合でも、過去の契約・受注データには変更前の名称を保持する。

**実装方針**

契約・受注レコードは選択時点の表示名（ラベル）をスナップショットとして保持する。選択肢IDと合わせて保存することで、現在の選択肢マスタと過去の表示名を独立して管理できる。

```
受注レコード
  ├── industry_type_id    → option_values.id（参照用）
  └── industry_type_label → 選択時点のラベル（例：飲食業）← マスタ変更の影響を受けない
```

> ⚠️ **差分 / 要確認**: 現行スキーマ（`Column.md` 準拠）は `customers.industry` / `industry_sub`（string(50)）、`order_work_details.business_type` 等に **選択時点の値（`option_values.value` または label 文字列）をそのまま保持**しており、「`*_id` + `*_label` のペア」構造にはなっていない（旧システム互換の文字列カラム）。値文字列自体がスナップショットとして機能するため「旧名称保持」の業務要件は満たすが、`option_values.id` への参照は持たないため「現在のマスタとの突合（どの選択肢由来か）」はできない。R5 の入力チェック設定・R7 の移行マッピングで `*_id` 併設の要否を判断する。

---

### テーブル設計

> ✅ 以下は現行 `db/schema.rb` と一致（R2 実装済み）。加えて両テーブルに `created_by_id` / `updated_by_id`（`TracksUser`）・`created_at` / `updated_at` を持つ。

**`option_groups`（値グループ）**

| カラム | 型 | 内容 |
|---|---|---|
| `id` | UUID | 主キー |
| `key` | string (unique, not null) | システムキー（例：`industry_type`）。作成後変更不可 |
| `label` | string (not null) | 表示名（例：業種） |
| `description` | text / null | 説明 |
| `sort_order` | integer (default 0) | 表示順 |
| `is_active` | boolean (default true) | 有効/無効 |

**`option_values`（値・選択肢）**

| カラム | 型 | 内容 |
|---|---|---|
| `id` | UUID | 主キー |
| `option_group_id` | UUID (FK, not null) | option_groups.id への参照 |
| `parent_id` | UUID (FK) / null | 親選択肢のID（self-reference）。ルートの場合はNULL。同一グループ内のみ |
| `value` | string (not null) | 内部値（例：`food`）。`(option_group_id, value)` で unique |
| `label` | string (not null) | 表示名（例：飲食業） |
| `depth` | integer (default 0) | 階層の深さ（ルート=0。親から自動算出） |
| `sort_order` | integer (default 0) | 同一階層内の表示順 |
| `is_active` | boolean (default true) | 有効/無効 |

---

## 付録A. Rails版改訂サマリ（2026-08-19）

**章別の実装状況一覧**

| 章 | 内容 | 状況 | フェーズ | 主な差分・要確認 |
|---|---|---|---|---|
| 1 | ユーザ管理 | ✅ | R0/R1 | 一覧検索条件未実装（R6）。所属部署カラム無し。無効化はフラグ編集 |
| 2 | ログイン管理 | ✅ | R0/R3/R4 | 営業担当者はパスワード無し（OTP）。Customer は recoverable なし。2-4（メールOTP・IP許可リスト）を追加。session 有効期限・force_ssl は R8 |
| 3 | 権限管理 | ✅ | R0/R1 | organizations/NestedSet 廃止 → agency_groups / agencies / users.agency_*_id 直管理。2層認可（RBAC+Pundit）。実務運用者の「一部制限」定義は未確定。販売許可UI未実装 |
| 4 | 顧客一覧 | ✅ | R2 | `jasmin_customers` → `customers`（決定D）。検索は q のみ（R6）。統合ビュー・名寄せは R6 |
| 5 | 顧客詳細 | ✅ | R2 | フィールド定義確定済み（Column.md §8）。タブ未実装。退会済みの一覧既定除外未実装。代理店ユーザは新規作成不可 |
| 6 | 申込登録 | ✅/⏳ | R3 / R5 | フォーム基盤・一括生成トランザクションは R3 実装済み。クレカ・署名・重説・確認書は R5 |
| 7 | 決済連携 | ⏳ | R5 | PaymentTransaction 手実装状態機械・専用キュー・ret_url 受け口方針を記載。Q-25〜27/36〜39 がブロッカー |
| 8 | 入力チェック設定 | ⏳ | R5 | InputCheckRule 案。FormField.validation_rules との役割分担 |
| 9〜12 | 不備チェック / 差戻し / キーワード / 確認コール | ⏳ | R5 | 契約ステータス（1本）に統合した状態機械 + contract_reviews。状態機械 → 重説の順 |
| 13〜14 | 契約書作成 / 参照 | ⏳ | R5 | ContractDocument + Active Storage + PDF gem 要選定 |
| 15 | 案件一覧 | ✅ | R2 | Bridge/BridgePlus は単一 orders。メール検索未実装（R6）。手動作成が存在 |
| 16 | 監査ログ | ✅ | R0 | Auditable / AuthAuditable。ログアウト未記録。汎用検索画面未実装（R6） |
| 17 | 問い合わせ管理 | ✅/⚠️ | R4 | 顧客側フォーム・メールリンク返信は未実装（R6）。返信テンプレ（FAQ）は要否・フェーズ要確認 |
| 18 | 選択肢マスタ | ✅ | R2 | parent_id 方式。`*_id + *_label` スナップショット構造は未採用（文字列保持） |

**関連ドキュメント（Rails版）**: `03-rails-architecture-proposal.md`（技術決定）/ `04-rails-implementation-plan.md`（R0〜R8）/ `review/review-05-legacy-design-docs-sweep.md`（棚卸し）/ `Column.md`（テーブル定義）/ `payment-integration.md`（決済）/ `status-naming-analysis.md`（Q-B）/ `form-template-mapping.md`（R3）/ `board-implementation-options.md`（R4 Inquiry 統合）/ `customer-merge-design.md`（R6）/ `contract-confirmation-docs.md`（重説）/ `notification-matrix.md`（通知）。削除済み（旧Laravel側に残存）: `Inquiry-email.md` / `ftlog-port.md` / `basic-cost.md` / `branch-merge-policy.md` / `test-code-plan.md` / `test-file-review.md` / `remaining-tasks.md` / `impl-plans/`。

---

*このファイルは要件追加に応じて随時更新します。*
