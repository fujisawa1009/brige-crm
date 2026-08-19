# レビュー: `01-laravel-current-analysis.md` の突き合わせ検証

- 対象: `projects/brige-crm/requirements/design/01-laravel-current-analysis.md`（作成2026-08-14）
- 検証方法: 実体 `projects/boilerplate-vue-env/laravel/`（コード）および同 `requirements/`（要件群）を直接開いて1つずつ照合。推測なし。
- 検証者: CTO（現場肌のリードエンジニア視点）
- 検証日: 2026-08-15

---

## ✅ 確認済み（正確だった主張・代表例）

- **技術スタック（§1）**: `composer.json` で Laravel `^12.0` / inertiajs/inertia-laravel `^2.0` / laravel/fortify `^1.31` / laravel/horizon `^5.32` / laravel/reverb `^1.10` / spatie/laravel-permission `^6.18` / spatie/laravel-activitylog `^4.9` / kalnoy/nestedset `^6.0` / maatwebsite/excel `^3.1` / tightenco/ziggy `^2.5` / pestphp/pest `^3.8` を確認。`package.json` で Vue `^3.5.13` / @inertiajs/vue3 `^2.1.0` / reka-ui / tailwindcss `^4.1.1` / lucide-vue-next / vue-i18n / laravel-echo+pusher-js / vite `^7.0.4` を確認。Pinia等の状態管理ライブラリは `dependencies` に存在せず「状態管理なし」の主張も正しい。
- **kalnoy/nestedset「未使用の残骸」**: `app/Models/ContractCondition.php`・`app/Models/OptionValue.php` とも `NodeTrait` 不使用。`grep -rln "NodeTrait" app/` は `app/Models/Concerns/ExNodeTrait.php` 自身のみヒットし、どのモデルからも参照されていない。**development-plan.md 60行目「契約条件（NestedSet）」という記載の方がむしろ古い/不正確**（後述⚠️参照）。
- **`AGENTS.md` の React 誤記**: `AGENTS.md:8` に `* React` と明記されているのを確認。実装は Vue（`package.json`）。指摘は正確。
- **JasminCustomer P2-4拡張37カラム**: `app/Models/JasminCustomer.php` の `$fillable` を実カウント（契約者情報4＋担当者9＋連絡先2＋請求書送付先8＋業種情報5＋外部連携9＝**37**、基本8カラムは除く）。主張と完全一致。
- **JasminOrder「fillable約90カラム」**: `app/Models/JasminOrder.php:42-143` を実カウントすると **88カラム**（`awk`集計で確認）。「約90」は近似として妥当。
- **console.php スケジュール**: `routes/console.php` を実読。`notify:inactive-users` dailyAt('22:10') / `csv-exports:cleanup` hourly / `notifications:dispatch-scheduled` everyMinute / `model:prune`(SystemNotification) dailyAt('02:00') と完全一致。
- **web.php 構成**: prefix `admin`・middleware `['auth', 'check.permission']`（`routes/web.php:41`）を確認。`/permissions`, `/permissions/scan`, `/permissions/toggle/{role}` も存在（同50-52行）。
- **form.php / mypage.php**: `form.php` は `form.guest`/`form.auth` ミドルウェアで step1→`step/{n}`→complete の動的マルチステップ構成を確認。`mypage.php` は `guest:customer`/`auth:customer` で login+dashboard のみと確認。
- **3ガード構成**: `config/auth.php:41-50` に `web`(provider: users) と `customer`(provider: customers, model: `JasminCustomer`) の2ガードを確認。受注入力はガード不使用でセッション管理（`app/Http/Controllers/SalesForm/AuthController.php` で `session(['form.sales_rep_id' => ...])`）という主張も一致。
- **CheckActionPermission**: `app/Http/Middleware/CheckActionPermission.php:20-29` で `Route::currentRouteAction()` から `Controller@method` 文字列を作り `$user->can($permission)` → `abort(403, ...)` を実装。主張と完全一致。
- **PermissionScannerService**: `app/Services/PermissionScannerService.php:29-77` でコントローラを `ReflectionClass` 走査し `Permission::firstOrCreate` → 不要分を `delete()` する実装を確認。主張と完全一致。
- **ロール4種**: `database/seeders/DatabaseSeeder.php:18-21` で `admin` / `実務運用者` / `代理店グループ用` / `代理店用` を `Role::firstOrCreate` しているのを確認。名称も完全一致。
- **PaymentTransaction 状態機械**: `app/Enums/PaymentTransactionStatus.php` に7状態（pending/authorized/captured/failed/unknown/canceled/refunded）と `allowedTransitions()` を確認。`app/Models/PaymentTransaction.php` の `markCaptured/markFailed` が `guardNotFromUnknown()` で unknown起点を禁止し、`confirmCaptured/confirmFailed` のみ unknown からの遷移を許可する実装（69-152行）を確認。`existsUnsettledForOrder()`（158-168行）も存在。「unknownをfailedに丸めない」設計は主張通り正確。
- **決済の業務フロー未接続**: `grep -rl "PaymentTransaction" app/Http/Controllers/` は**0件**。`app/Services/Payment/` 配下に `NetmoveGateway`（interface）/`HttpNetmoveGateway`/`MockNetmoveGateway`/`PaymentConfirmationService`/`ReconciliationSource`/`PaymentLogMasker` 等が存在するが、コントローラから未参照。主張と一致。
- **JasminOrderWorkDetailのPII平文保持**: `database/migrations/..._create_jasmin_order_work_details_table.php` で `system_account_pass`/`google_account_pass`/`instagram_pass`/`facebook_pass` が全て `$table->string(...)->nullable()`（暗号化・ハッシュ化なし）。`app/Models/JasminOrderWorkDetail.php` の `casts()` も `opening_date=>date` のみで暗号化castなし。主張は正確。
- **要件ドキュメント地図（§6）**: `requirements/design/legacy-research/00〜14` 全14ファイル実在確認。`basic-design.md` は `wc -l` で **1136行**と完全一致。`Column.md`/`payment-integration.md`/`business-flow-analysis.md`/`ftlog-port.md`/`development-plan.md` すべて実在。「ほか」として挙げた顧客名寄せ/出力定義/ステータス用語/PII取扱/リリース準備も `customer-merge-design.md`/`export-profile-design.md`/`status-naming-analysis.md`/`pii-handling-rules.md`/`release-readiness.md` に対応する実ファイルを確認。
- **テスト構成（§7）**: `find tests/Feature -name "*.php" | wc -l` = **40**（「約40ファイル」に完全一致）。決済・契約フロー関連のテストファイルは0件（`find tests -iname "*payment*" -o -iname "*contract*"` 該当なし）で、T-1負債の主張とも整合。
- **OptionValue階層構造**: `app/Models/OptionValue.php` は `parent_id` の `belongsTo`/`hasMany` 自己参照のみで nestedset 不使用。主張通り。
- **自動採番のcount()+1脆弱性（§8-13）**: `JasminOrder`(`ORD{年}{4桁}`)・`JasminCustomer`(`C-%06d`)・`Inquiry`(`INQ-%06d`)いずれも `static::count() + 1` パターンで実装されているのを確認（該当各モデルの `booted()`）。競合に弱いという指摘は正確。
- **git履歴とドキュメント日付の整合性（項目8）**: `git -C laravel log -1 --format=%ci` = `2026-07-26 14:37:16 +0900`。01文書の作成日（2026-08-14）より前であり、**文書作成後にLaravel側で新規コミットは無い**。記載が古くなっている懸念は無し。

---

## ⚠️ 誤り・要修正

### 1. モデル数「全41モデル」は誤り。実際は**39個**

`app/Models/` 直下の `.php` ファイルは39個（`find app/Models -maxdepth 1 -name "*.php" | wc -l` = 39）。`app/Models/Concerns/`（`HasUuids.php`/`TracksUser.php`/`ExNodeTrait.php`）はトレイトであり、モデルではない（`find app/Models -name "*.php" | wc -l` の生値42は Concerns の3ファイルを含んだ数字で、そのまま使うとズレる）。`Permission.php`/`Role.php` はSpatieの `Model` サブクラスを継承しているため実質モデルとしてカウントしてよいが、それでも合計は39。「全41モデル」は根拠不明の誤カウント。→ 見出しを「全39モデル」に訂正すべき。

### 2. §4「レコードレベル参照制御は InquiryController のみ部分実装」は不正確・実態より楽観的

実際にコントローラを1つずつ確認したところ、record-level scopingの実装状況はより粒度が細かく、01の要約は実態を過小/過大の両方で取り違えている。

- **`JasminOrderController::index()`**（`app/Http/Controllers/Admin/JasminOrderController.php:30-41`）は InquiryController と同じ agency_id/agency_group_id スコープを実装済み（`if ($user->agency_id) { $query->where('agency_id', ...) } elseif ($user->agency_group_id) { $query->whereIn('agency_id', $agencyIds); }`）。**InquiryController だけではない。**
- 一方で **`JasminOrderController::show/edit/update/destroy`**（同ファイル85, 147, 203, 267行目）には代理店スコープのチェックが一切ない。Route Model Binding で UUID を渡せば誰でも他代理店の案件を閲覧・編集できる可能性がある（IDOR懸念）。一覧だけ絞ってあっても詳細/更新系が素通しでは実質的に保護になっていない。
- **`JasminCustomerController::index()`**（同ディレクトリ、1-40行目付近）に至っては agency_id によるスコープが**まったく無い**（`show_withdrawn`/`search`/`customer_number`/`status`/`applied_from`/`applied_to` のフィルタのみ）。顧客一覧は代理店ユーザでも全件見えている可能性が高い。

→ 01の「InquiryControllerのみ部分実装」という要約は、JasminOrderControllerの一覧スコープを見落とし、かつ「一覧だけ絞られていて詳細は無防備」という一覧/詳細の非対称性・JasminCustomerControllerの完全な未実装という、Rails側P4-1設計上もっと重要な粒度の情報を落としている。**Rails移植時は「コントローラ単位でindexのみ」という簡略図ではなく、CRUDアクション単位でのPunditスコープ適用漏れの棚卸しが必要。**

### 3. development-plan.md の T-2（`sales_rep_code` 複合ユニーク説）と実スキーマが矛盾。01文書はこれを未検証のまま踏襲

`requirements/development-plan.md:91` は「`sales_representatives.sales_rep_code` が複合ユニーク（設計はグローバルユニーク）→ 是正必要」（T-2）としており、01文書 §8-9 もこれをそのまま「営業担当者CDグローバルユニーク化（T-2）も是正」と引き写している。

しかし実際のマイグレーション `database/migrations/2026_05_13_000006_create_sales_representatives_table.php:15` は
```php
$table->string('sales_rep_code', 50)->unique(); // グローバルユニーク
```
であり、**単一カラムの一意制約＝既にグローバルユニーク**。同テーブルへの後続ALTERマイグレーションは無し（`grep -rln "sales_representatives" database/migrations/*.php` で全5ファイル確認、複合ユニーク化した形跡なし）。development-plan.md は2026-07-26付レビュー反映後もこの記述を維持しており（368行目）、スキーマとの矛盾がそのまま残っている。

なお `app/Http/Controllers/SalesForm/AuthController.php:28-31` のログイン検索は `agency_id` + `sales_rep_code` で絞り込む実装のため、業務運用上は「代理店CD＋営業担当者CD」の組み合わせで認証する設計意図自体は正しく反映されている（グローバルユニークはこの組み合わせの部分集合なので矛盾なく成立する）。問題は **development-plan.md の「現状は複合ユニーク」という前提記述が実スキーマと食い違っている**点であり、01文書はこの食い違いを検証せずに転記している。

---

## ➕ 不足・追加すべき情報

- **PII平文保持の定量データが01文書に無い**: `requirements/design/pii-handling-rules.md:21` に、案件CSV238フィールド中の平文認証情報の実測値（システムアカウント63/166・Instagram 66/67・Facebook 126/127・Google 236/237がID/PASS平文、`legacy-research/11`§4）が記載されている。01文書は「懸念（Q-D未決）」とだけ書いており、この深刻度（ほぼ全件が平文）を伝えていない。Railsの暗号化優先度（P5-10/C-3）を決定者に判断してもらう際、この定量データを添えるべき。
- **AGENTS.mdはReactだけでなくPHPバージョンも実態と不一致**: `AGENTS.md:7` は `* PHP 8.4` と記載しているが、実際の `composer.json` の制約は `"php": "^8.2"`。01文書は「Reactの誤記」のみ指摘しており、このPHPバージョンの食い違いは触れていない（実害は小さいが、AGENTS.mdの信頼性が「Reactだけの単発ミス」ではなく複数箇所で古いことを示す傍証）。
- **JasminOrderController/JasminCustomerControllerのアクセス制御実装粒度の一覧化**（上記⚠️2の詳細）は、Rails P4-1着手前の棚卸しとして `projects/brige-crm` 側のRails移植設計に反映すべき重要情報。

---

## ❓ 要決定者確認・未決事項

1. **T-2の実態確認**: development-plan.md の「`sales_rep_code` は現状複合ユニーク」という記述は実スキーマ（既にグローバルユニーク）と矛盾している。これは (a) development-plan.md 側の記述が古いだけで実装は既に是正済みなのか、(b) 何か別の理由で「実質複合ユニーク」とみなす運用上の制約が別途あるのか、laravel側の開発担当（もし決定者が把握していれば）に確認したい。誤りだった場合、development-plan.md の T-2 行・P2-10・P4-10 の記述を訂正する必要がある（ただしこれは `laravel/` リポジトリ側のドキュメントであり、本レビューの書き込み権限外）。
2. **P4-1（レコードレベル参照制御）の実態は「InquiryControllerのみ」ではなく複数コントローラでバラバラに部分実装されている**ことが判明した。Rails移植のPunditスコープ設計を始める前に、全Adminコントローラ（現状 admin配下で resource化されているもの約20+）をCRUDアクション単位で棚卸しする追加調査が必要かどうか、着手時期の判断を決定者に仰ぎたい。
3. **Q-D（SNS認証情報平文を新システムへ運ぶか）は`pii-handling-rules.md`時点でも決定者確認待ちのまま**（同ファイル末尾「決定者確認待ち」表記）。上記の定量データ（ほぼ全件平文）を踏まえて優先度を上げるかどうかの判断が必要。

---

## まとめ

01文書は技術スタック・ルーティング・スケジュール・認証ガード構成・決済状態機械・PII懸念・要件ドキュメント地図など大半の主張が実ソースと一致し、精度は高い。一方で (1) モデル数「41」は実際は39という単純な数え誤り、(2) レコードレベル参照制御の実装範囲を「InquiryControllerのみ」と過度に単純化した記述（実際はJasminOrderControllerのindexにも実装があり、逆にJasminOrderの詳細/更新系とJasminCustomer全体は完全に無防備というより深刻な実態）、(3) development-plan.md由来のT-2記述を実スキーマと突き合わせずに転記した点、の3つは移植判断に影響しうるため修正を推奨する。
