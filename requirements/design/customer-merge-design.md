# P4-4 顧客マイページからの顧客統合（名寄せ）設計案

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/customer-merge-design.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。フェーズ対応: **R6（運用強化）— 未実装**。突合対象: `db/schema.rb`（2026-08-19時点）/ `app/models/customer.rb` `store.rb` `order.rb` `application.rb` / `app/models/concerns/{otp_authenticatable,auditable,auth_auditable}.rb` / `app/policies/*` / `app/controllers/mypage/*`。
> - 実装状況: **本機能（統合キー発行・移管トランザクション・統合履歴テーブル）は R6 で新規実装。現時点でコード・テーブルとも存在しない。** 前提となるマイページ（Customer の Devise 認証＋メールOTP、ダッシュボード）は R4 で実装済み。
> - 04 R6 の要求: 「lockForUpdate・TOCTOU再検証・ワンタイム消費・代理店またぎ検知の高リスク並行処理は **request spec 必須**」（04 R6 本文 2026-08-15追記）。本書 §8 に spec 必須事項として再掲。
> - Laravel時代のフェーズ番号（P4-4 等）は残し、対応する R フェーズを併記する。

> **ステータス: 設計案 → Q-11〜13 は本書の推奨どおり仕様決定済み（D-12・2026-07-26。`development-plan.md` §8: 不可逆／論理削除＋認証・メールのみ無効化／24hワンタイム・5回失効）。実装は R6（未着手）。**
>
> 参照元:
> - `requirements/development-plan.md` §P4-4 詳細（フロー・タスク a〜f・論点 Q-11〜13）
> - ~~`requirements/design/remaining-tasks.md` 5-1（顧客統合フロー メモ）~~（削除済み・旧Laravel側に残存。内容は本書 §1 に取り込み済み）
> - `requirements/design/pii-handling-rules.md`（PII 取扱・Q-12 の判断材料）
> - ~~`requirements/design/ftlog-port.md` §2（メールOTPの有効期限・試行制御の先例）~~ → Rails版では `app/models/concerns/otp_authenticatable.rb`（`OTP_VALID_FOR = 10.minutes` / `OTP_MAX_ATTEMPTS = 5`）が一次情報
> - `requirements/design/legacy-research/09-data-cleansing.md`（移行時名寄せ C-3/C-5 との関係。R7）
> - `requirements/design/03-rails-architecture-proposal.md` §3（Pundit 参照制御）/ §4（認証系統）、`04-implementation-plan.md` R6

---

## 0. 前提となる実装事実（コード調査結果・Rails版 2026-08-19 突合）

| 事実 | 根拠（Rails版） | Laravel設計時からの差分 |
|---|---|---|
| 顧客は `Customer`（決定D。Devise `database_authenticatable, lockable, timeoutable` + `OtpAuthenticatable` + `AuthAuditable`）。`:rememberable` `:recoverable` `:registerable` は**未使用** | `app/models/customer.rb` | `remember_token` 列は存在しない（後述 §1-2 手順5 を修正） |
| マイページは `mypage` section（決定C）。現状は login / OTP / dashboard / logout のみ（`Mypage::SessionsController` `Mypage::OtpsController` `Mypage::DashboardController`） | `config/routes.rb` `devise_for :customers, path: "mypage"` / `namespace :mypage` | 同等（Laravel `routes/mypage.php` と最小構成が一致） |
| `customers.email` は **nullable + unique index**（`index_customers_on_email`）。`encrypted_password` は `not null default ""`（空文字＝ログイン不能） | `db/schema.rb` customers | Laravel は `password` nullable。Rails版は「空文字で無効化」に読み替え |
| 退会は論理ステータス `status = CustomerStatus::CODE_WITHDRAWN`。`Customer.active` scope で除外。`active_for_authentication?` が withdrawn を弾く | `app/models/customer.rb` | 同等 |
| 店舗: `stores.customer_id`（not null, FK **cascade**、`has_many :stores, dependent: :destroy`）。案件: `orders.customer_id`（not null, FK **restrict**、`has_many :orders, dependent: :restrict_with_error`）。申込: `applications.customer_id`（nullable, FK **nullify**。`Application belongs_to :customer, optional`） | `db/schema.rb` add_foreign_key / 各モデル | 同等（`jasmin_` プレフィックス除去のみ）。**stores が cascade** である点は移管順序に注意（A を destroy すると店舗が消えるため、A は絶対に destroy しない） |
| 案件は `orders.agency_id`（not null）を自身で持ち、`OrderPolicy::Scope` は `orders.agency_id` で絞る。店舗は agency を持たず `StorePolicy::Scope` が `customer.agency_id` 経由で絞る | `app/policies/order_policy.rb` `store_policy.rb` | 代理店またぎ統合時の見え方に影響（§1-2 注意点） |
| 問い合わせ `inquiries` は **`order_id` にぶら下がる**（顧客 FK を持たない）。`inquiry_message_recipients` は `recipient_type/recipient_id` ポリモーフィック（`Customer` を含む）+ `resolved_email` を送信時に静的保持 | `db/schema.rb` inquiries / inquiry_message_recipients、`InquiryMessageRecipient::RECIPIENT_TYPES` | 同等 |
| 一斉通知の宛先履歴 `notification_recipients` は `recipient_type/recipient_id` ポリモーフィック + 送信時の `email` を静的保持 | `db/schema.rb` notification_recipients | 同等（列名 `to_email`→`email`） |
| 画面内通知 `system_notifications` は `recipient_type/recipient_id` ポリモーフィック（`Customer has_many :system_notifications, as: :recipient, dependent: :destroy`）。`expires_at` あり・30日 prune（`config/recurring.yml`） | `app/models/system_notification.rb` | 同等（`notifiable`→`recipient`） |
| ログイン履歴は専用テーブルではなく **`AuditLog`**（`user_type/user_id` に `Customer` も入る。`AuthAuditable::AUTH_ACTIONS`）。全モデル変更は `Auditable` concern（`TRACKED_FIELDS`。Customer: name/status/agency_id/…、Store: store_name/customer_id/is_active、Order: customer_id/store_id/… を追跡）で `audit_logs` に記録 | `app/models/audit_log.rb` / `app/models/concerns/auditable.rb` `auth_auditable.rb` | spatie activitylog → `AuditLog`。`causer_type/causer_id` → `user_type/user_id`、`subject_type/subject_id` → `resource_type/resource_id`、`log_name` → `action`/`source` |
| 顧客レベルの外部連携キー: `netmove_member_id` / `netmove_registered_at`（決済会員ID）・`sales_mgmt_customer_code`・`lbc_code`・`agency_customer_code` | `db/schema.rb` customers | 同等 |
| メールOTPの先例: `otp_code_digest / otp_code_expires_at / otp_attempts` 列、**試行上限5回・有効期限10分** | `app/models/concerns/otp_authenticatable.rb` | ftlog-port §2 → 実装 concern が正 |
| レート制限: `rack-attack`（`config/initializers/rack_attack.rb`。現状は users のパスワードリセット・OTP のみ） | 同左 | Laravel `throttle` ミドルウェア → rack-attack throttle |
| 非同期処理: Solid Queue（`ApplicationJob`）。定期処理: Solid Queue recurring（`config/recurring.yml`）。メール: ActionMailer `deliver_later` | `config/queue.yml` `recurring.yml` | Horizon/scheduler → Solid Queue |
| 参照制御: Pundit（`AgencyScoped` concern。staff=全件 / 代理店=自代理店 / グループ=配下） | `app/policies/concerns/agency_scoped.rb` | Laravel は未実装（P4-1）だったが Rails版は R1 で実装済み。本機能の管理画面側はこれに乗る |

---

## 1. フロー設計（タスク b, c, d, e）

### 1-1. シーケンス

登場者: 顧客A（吸収される側・退会化）、顧客B（存続側）、システム。

```
顧客A                          システム                            顧客B
  │ ①マイページで「統合キー発行」   │                                  │
  ├──────────────────────────────►│                                  │
  │                               │ 統合キー生成（平文は保存しない）      │
  │                               │ customer_merge_keys にハッシュ保存   │
  │ ②Aの登録メールアドレスへキー送付 │                                  │
  │◄──────────────────────────────┤                                  │
  │   （画面にはキーを表示しない）    │                                  │
  │                               │      ③Bがマイページでキー入力         │
  │                               │◄─────────────────────────────────┤
  │                               │ 検証: ハッシュ一致・期限内・未使用・    │
  │                               │       試行回数内・A≠B・両者 active    │
  │                               │      ④統合内容の確認画面              │
  │                               │  （Aの顧客番号・マスク済み名称/メール・ │
  │                               │   移管される店舗/案件の件数を提示）     │
  │                               ├─────────────────────────────────►│
  │                               │      ⑤Bのパスワード再入力＋最終確認    │
  │                               │◄─────────────────────────────────┤
  │                               │ ⑥移管トランザクション実行（§1-2）      │
  │ ⑦完了通知メール（Aの旧アドレス）  │      ⑦完了通知メール（B）            │
  │◄──────────────────────────────┼─────────────────────────────────►│
```

ポイント:
- **キーは画面に表示せず、Aの登録メールアドレスにのみ送る**。これにより「Aのセッション」だけでなく「Aのメール所有」も証明される（§5）。
- ④の確認画面を挟み、Bが「どの顧客を吸収するのか」を目視確認してから⑤で確定する。誤入力キーが偶然他人のキーに一致した場合の誤統合を業務的にも防ぐ。
- 実装は UI（Controller）と移管本体を分離する: `CustomerMergeService.new(source:, target:, key:).call`（`app/services/customer_merge_service.rb`）。移行後クリーンアップ（§6）や将来の管理画面主導マージで再利用するため。
- **Rails版の画面構成（Hotwire + ERB。決定B）**:
  - `Mypage::MergeKeysController#create`（①発行。Turbo で「送信しました」を差し替え表示）
  - `Mypage::CustomerMergesController#new`（③キー入力フォーム）→ `#confirm`（④確認画面。POST でキー検証のみ・副作用なし）→ `#create`（⑤⑥実行。パスワード再入力を同フォームに含める）
  - いずれも `Mypage::BaseController` 配下（`authenticate_customer!` + OTP 済み）。`mypage` section の `SystemPermission` は起動時 sync で自動登録される（決定C。`mypage` はロール割当対象外＝ログイン済み顧客なら通れる固定運用）。
  - 発行/入力 UI の配置（ナビゲーション）は P4-9（マイページ機能拡充。R6）の画面設計と同時に確定する（§7 備考）。
- **メール**: `CustomerMergeMailer#key_issued`（A宛）/ `#completed`（A旧アドレス・B宛）。`deliver_later`（Solid Queue）。

### 1-2. 移管トランザクション（タスク d）

1つの DB トランザクションで以下を実行する。順序は固定。

```ruby
ActiveRecord::Base.transaction do
  # 1. A・B の行を SELECT ... FOR UPDATE（★id 昇順で取得しデッドロック回避）
  a, b = Customer.where(id: [source.id, target.id]).order(:id).lock.to_a  # ← 2件を一括ロック
  # 2. 統合キーを再検証して consumed_at / consumed_by_customer_id を刻む（ワンタイム消費）
  #    CustomerMergeKey.where(id: key.id, consumed_at: nil, canceled_at: nil)
  #                    .where("expires_at > ?", Time.current).update_all(consumed_at:, consumed_by_customer_id:) == 1
  #    でなければ raise CustomerMergeService::KeyAlreadyConsumed（2本目の並行リクエストはここで落ちる）
  # 3. 事前スナップショット作成: A の顧客行全カラム（as_json）＋移管対象の store/order/application の id 一覧
  # 4. 移管（update_all = コールバック/バリデーション/Auditable を通さない一括UPDATE。理由は下記「注意点」）
  Store.where(customer_id: a.id).update_all(customer_id: b.id, updated_at: Time.current)
  Order.where(customer_id: a.id).update_all(customer_id: b.id, updated_at: Time.current)
  Application.where(customer_id: a.id).update_all(customer_id: b.id, updated_at: Time.current)
  # 5. A の退会化（Q-12 の決定に従う。推奨案 c: status=CODE_WITHDRAWN、
  #    email を merged+<uuid>@invalid.local へ退避、encrypted_password="" (空文字=ログイン不能)、
  #    otp_code_digest/otp_code_expires_at=nil、unlock_token=nil）  ※ a.update! で Auditable に記録させる
  # 6. customer_merges（統合履歴）へ 1 行 INSERT（スナップショット込み・§2-2）
  # 7. AuditLog へ action="customer_merged"、resource_type="Customer"、resource_id=b.id、
  #    metadata={merge_id:, source_customer_id:, moved: {...件数}} で 1 件記録（Current.user は顧客B。
  #    Auditable#audit_record は Current.user 前提のため、サービス内で AuditLog.create! を直接呼ぶ）
end
# commit 後（トランザクション外）:
#  8. 完了メール送信（A旧アドレス＋Bアドレス。CustomerMergeMailer deliver_later）
#  9. Aの全セッション破棄（Devise は session に authenticatable_salt=encrypted_password 先頭29文字を保持するため、
#     手順5の encrypted_password 変更で既存 warden セッションは自動失効する。remember_token は存在しない）
```

**トランザクション境界と失敗時のリカバリ:**

| 失敗点 | 挙動 | リカバリ |
|---|---|---|
| 手順 1〜7 のどこかで例外 | 全ロールバック。キーは未消費のまま残る | Bが再入力すればそのまま再試行できる（冪等） |
| commit 成功・手順 8（メール）失敗 | データは統合済み。メールのみ未達 | 送信は ActionMailer `deliver_later`（Solid Queue）でリトライ。統合自体は `customer_merges` が真実源 |
| 二重送信（Bの二度押し・並行リクエスト） | 手順 2 のワンタイム消費（`consumed_at IS NULL` 条件付き `update_all` の戻り値 1 件チェック）で 2 本目は検証失敗 | エラー表示のみ。副作用なし。**request spec 必須（04 R6）** |
| A に紐づく行が処理中に増える | 手順 1 の行ロック中は A 側の書込み（`Customer` 行を `lock!` する経路）が待たされる。UPDATE は WHERE 句一括なのでロック取得後の全行が対象 | — ※`stores`/`orders` の INSERT は customers 行をロックしないため、厳密には移管UPDATE後に A 宛て INSERT が滑り込む余地がある。申込（R3 `Form::ApplicationSubmissionService`）は退会顧客へ紐づけないため実害は限定的だが、必要なら手順5の退会化を先に行い「withdrawn への新規紐づけを拒否する」バリデーションを Store/Order に持たせる（要検討） |

注意点:
- `orders.customer_id` は FK restrict のため「付け替え」のみで削除は発生しない。設計と整合。`stores.customer_id` は FK cascade だが A を削除しない（論理退会のみ）ため発火しない。
- `Auditable` concern はモデル単位の save で発火する。店舗・案件が多い顧客では `update_all`（一括UPDATE）にし、明細ログの代わりに `customer_merges` のスナップショット＋`customer_merged` AuditLog 1 件に集約する（ログ洪水の回避。移管対象 id 一覧は履歴に残るので追跡性は落ちない）。※`update_all` は R2 で追加した `Order` の付け替え防御（`Admin::OrdersController#strip_ownership_params!` = コントローラ層）を通らないが、本サービスは信頼された内部経路であり意図どおり。
- **A≠B・両者 `status` が active（`Customer.active`）・同一メール顧客の自己統合でない**ことを手順 2 で必ず再検証する（発行時 OK でも実行時に退会済みになっている可能性がある。TOCTOU。**request spec 必須**）。
- **代理店またぎ統合**: 顧客・案件は各自 `agency_id` を持つためデータ上は成立するが、統合後は「B（agency X）の配下に agency Y の案件がぶら下がる」状態になり、`OrderPolicy::Scope`（`orders.agency_id`）と `StorePolicy::Scope`（`customer.agency_id`）の絞り方が異なるため、代理店ユーザから見て「顧客詳細には店舗が見えるが案件は見えない」等の非対称が生じる。**代理店をまたぐ統合を許すかは業務判断**（本設計では「許可するが `customer_merges` に両者の agency_id を記録し、`source_agency_id != target_agency_id` の履歴を管理画面（staff 限定）で検知可能にする」を暫定とする。**検知が効くことは request spec 必須**）。
- `netmove_member_id`（決済会員ID）等の**顧客レベル外部キーは移管しない**（Bは自分のものを維持、Aの値はスナップショットに保存）。ネットムーブ側の会員統合は自動では行われないため、決済連携（P3-2 = **R5**）確定後に運用手順として整理する。
- `SystemNotification`（Customer has_many dependent: :destroy）は A を destroy しないため残る（§4）。

---

## 2. データモデル案（タスク a, e）

いずれも **未作成（R6 で migration 追加）**。主キーは UUID（`gen_random_uuid()`）、`created_by/updated_by` は `TracksUser`、監査は `Auditable::TRACKED_FIELDS` に `"CustomerMergeKey" => %w[source_customer_id expires_at consumed_at canceled_at]` `"CustomerMerge" => %w[source_customer_id target_customer_id status reversed_at]` を追加する。

### 2-1. `customer_merge_keys` — 一時統合キー

| 列 | 型（Rails migration） | 説明 |
|---|---|---|
| id | uuid PK | |
| source_customer_id | uuid FK→customers（`on_delete: :restrict`） | 顧客A（発行者・吸収される側） |
| key_hash | string(64), index unique | キーの SHA-256（`Digest::SHA256.hexdigest`）。**平文は保存しない**（メール本文にのみ存在） |
| expires_at | datetime | Q-13。推奨 24 時間 |
| attempts | integer default 0 | B側の照合失敗回数。**5 回で失効**（`OtpAuthenticatable::OTP_MAX_ATTEMPTS` と同水準） |
| consumed_at | datetime nullable | 消費時刻（ワンタイム性の担保） |
| consumed_by_customer_id | uuid nullable | 消費した顧客B |
| canceled_at | datetime nullable | Aの再発行・手動取消で失効 |
| created_at / updated_at | | |
| issued_ip / issued_user_agent | string nullable | 発行時の端末情報（不正調査用。`Current.ip_address` / `request.user_agent`） |

- **有効キーは 1 顧客 1 本**: 再発行時は既存の未消費キーを `canceled_at` で失効させてから新規作成（部分ユニーク index `(source_customer_id) WHERE consumed_at IS NULL AND canceled_at IS NULL` で DB 側でも担保。PostgreSQL の partial index が使える＝決定A の利点）。
- 検証条件: `key_hash 一致 AND expires_at > now AND consumed_at IS NULL AND canceled_at IS NULL AND attempts < 5`（`CustomerMergeKey.usable` scope）。
- 期限切れ・消費済み行は 90 日で削除する定期処理（`config/recurring.yml` に `CustomerMergeKey.prune_stale!` を追加。`SystemNotification.prune_expired!` と同型）。

キー形式: **Crockford Base32 の 12 文字（`XXXX-XXXX-XXXX` 表示）= 60 bit エントロピー**（`SecureRandom.random_bytes` から生成）。
手入力する前提のため URL トークン（128bit hex）より短くするが、ワンタイム＋試行 5 回＋レート制限の下では総当たりは事実上不可能（§5）。

### 2-2. `customer_merges` — 統合履歴（タスク e）

| 列 | 型 | 説明 |
|---|---|---|
| id | uuid PK | |
| source_customer_id | uuid（FK は張らず id 値のみ保持。Aが将来物理削除されても履歴が壊れないように） | 顧客A |
| target_customer_id | uuid FK→customers（`on_delete: :restrict`） | 顧客B |
| merge_key_id | uuid FK→customer_merge_keys | 使用キー（管理者主導マージ=§6 では nullable） |
| source_snapshot | jsonb | Aの顧客行全カラム（**元 email・netmove_member_id 等の外部キー含む**。`encrypted_password`/`otp_code_digest` 等の秘匿列は除外） |
| moved_entities | jsonb | `{stores:[id...], orders:[id...], applications:[id...]}` 移管した行の id 一覧 |
| source_agency_id / target_agency_id | uuid | 代理店またぎ統合の検知用 |
| performed_at | datetime | |
| performed_ip / performed_user_agent | string nullable | B側の実行端末 |
| performed_by_type / performed_by_id | string / uuid | 実行主体（`Customer`=B本人 / `User`=管理者主導。§6） |
| status | string | `completed` / `reversed`（Q-11 で逆マージを残す場合のみ使用） |
| reversed_at / reversed_by_id | nullable | 予約列（Q-11） |

- この 2 テーブルが揃うと「いつ・誰が・何を・どの根拠（キー）で統合したか」「元に戻すのに必要な全情報」が 1 箇所に残る。
- `source_snapshot` は元メールアドレス等の PII を含むため、管理画面での表示は権限を絞り（`CustomerMergePolicy`: 一覧/詳細は staff のみ、`source_snapshot` の表示はさらに admin ロールに限定）、`pii-handling-rules.md` §3-1 のマスク方針を画面設計にも適用する。
- 管理画面 `Admin::CustomerMergesController`（index/show のみ）は `policy_scope(CustomerMerge)`。代理店ユーザに見せる場合は `target_agency_id`/`source_agency_id` のいずれかが自代理店のもの（`AgencyScoped` 拡張）。

---

## 3. Q-11〜13 の判断材料と推奨（→ 2026-07-26 D-12 で本節の推奨どおり決定済み。以下は判断材料の記録）

### Q-11 統合は不可逆か（逆マージを作るか）

| 観点 | 逆マージ機能を実装 | 不可逆（履歴＋手動復元） |
|---|---|---|
| 実装コスト | 高。統合**後**に B 側で増えた店舗・案件・決済・契約と、A 由来のものを恒久的に区別し続ける必要がある（全移管行に `merged_from` 相当の刻印が要る）。テストマトリクスも倍増 | 低。`customer_merges.moved_entities` + `source_snapshot` があれば rake タスク／手作業で復元可能 |
| 発生頻度 | 誤統合はキー入力＋確認画面＋パスワード再入力の 3 段ガードを抜けた場合のみ。稀 | 同左 |
| 復元可能性 | 完全自動 | スナップショットと id 一覧から**技術的には完全復元可能**。ただし統合後に B 側で A 由来案件に更新が入った場合の巻き戻し判断は人間が行う |
| リスク | 逆マージ自体が新たな攻撃面・バグ源になる | 復元は社内オペレーション（監査ログ付き）に限定され安全 |

**推奨: 不可逆（顧客向け逆マージ機能は作らない）。**
ただし §2-2 の履歴で「管理者による復元」は可能な状態を保証する。復元手順は rake タスク `customer:unmerge[merge_id]`（`lib/tasks/customer.rake`。管理者専用・P4-4/R6 スコープ外の予備実装または手順書のみ）として整理し、統合完了メールに「誤って統合した場合は◯日以内にサポートへ連絡」と記載する運用に倒す。

### Q-12 退会化した顧客Aの扱い

| 案 | 内容 | 長所 | 短所 / PII 観点 |
|---|---|---|---|
| a. 論理削除のみ | `status=CODE_WITHDRAWN` だけ | 最小実装 | **email の unique index が塞がったまま**（Bが後日メール変更で A の旧アドレスを使えない）。A のパスワードが生きていればログイン試行余地が残る（`active_for_authentication?` で弾かれるが、防御を1層に依存） |
| b. 即時完全匿名化 | 氏名・住所・電話等を即時マスク | PII 最小化 | 法定保存（契約・取引記録）や逆マージ材料が消える。案件側に顧客名の非正規化コピーが無い現行スキーマでは帳票再現に支障 |
| c. 論理削除＋認証情報とメールのみ無効化（**推奨**） | `status=CODE_WITHDRAWN`、`email` を `merged+<uuid>@invalid.local` に退避（元 email はスナップショットへ）、`encrypted_password=""`・`otp_code_digest=nil`・`unlock_token=nil`・全セッション失効（`encrypted_password` 変更で Devise の `authenticatable_salt` が変わり既存セッションは自動失効） | ログイン経路を完全遮断しつつ、unique 制約を解放。属性 PII は保持され契約参照・復元・監査が成立 | PII は残る（→保持期間ポリシーで対処） |

**推奨: c。** さらに PII の消し込みは「統合時」ではなく**退会顧客一般の保持期間ポリシー**（例: 退会後 N 年で匿名化バッチ）として別論点に切り出す。契約・決済関連の記録は法定保存があるため即時匿名化は不適（`pii-handling-rules.md` は開発・移行中の取扱ルールであり、本番の保持期間は P5-7 法務確認 = **R8（release-readiness.md G）**の一部として決めるのが筋）。なお A の `netmove_member_id`（PII 分類 C: 決済関連）はカラム上も保持されるため、退会顧客の閲覧権限は管理側でも絞る。

### Q-13 統合キーの有効期限

判断材料:
- リポジトリ内先例: メールOTP は **10 分・5 回**（`OtpAuthenticatable::OTP_VALID_FOR` / `OTP_MAX_ATTEMPTS`。User/Customer/SalesRepresentative 共通）。ただしこれは「同一人物が今まさにログイン中」の同期フロー。
- 統合キーは A のメール受信 → B アカウントでの入力、と**人手のリレーを挟む非同期フロー**（A/B が別担当者・別端末のケースを含む）。10 分では業務が回らない。
- 一般的なメール検証リンクの相場は 15 分〜24 時間。統合キーは「B の認証済みセッション（OTP 済み）」が無ければ単体で無価値であり、リスクはパスワードリセットより低い。

**推奨: 有効期限 24 時間・ワンタイム・照合失敗 5 回で失効・再発行で旧キー自動失効。** 値は `config/customer_merge.yml`（`Rails.application.config_for`）に置き環境変数で調整可能にする（運用してみて短縮する余地を残す）。

---

## 4. 統合対象外データの扱い（タスク f）

| データ | 現行構造（Rails版） | 方針案 |
|---|---|---|
| 問い合わせ（`inquiries` / `inquiry_messages`） | 顧客 FK を持たず `order_id` にぶら下がる。掲示板4種は R4 で Inquiry に統合済み（決定D-11） | **書き換え不要（案件の移管に自動追従）**。案件が B に付け替われば B のマイページから参照可能になる。「統合対象外」ではなく「自動で付いてくる」が正確 |
| 問い合わせメッセージ宛先履歴（`inquiry_message_recipients`。`recipient_type='Customer'` + `resolved_email`） | ポリモーフィック＋送信時メール静的保持 | **書き換えない（送信当時の事実として凍結）** |
| 一斉通知の送信履歴（`notifications` / `notification_recipients`） | `recipient_type='Customer'` + `recipient_id` + 送信時 `email` を静的保持 | **書き換えない（送信当時の事実として凍結）**。宛先履歴は監査記録であり、付け替えると「誰に送ったか」が改竄になる。B のマイページに A 宛の過去通知は表示しない仕様と明記 |
| 画面内通知（`system_notifications`） | `recipient` ポリモーフィック（Customer）。`expires_at` あり・30日 prune | **書き換えない**。A 宛未読は退会と同時に実質失効。重要イベントは案件詳細から確認できるため実害なし。※未読のみ B へ付け替える案もあるが、複雑さに見合う価値がないため不採用 |
| ログイン履歴・監査ログ（`audit_logs`。R0 実装済み） | `user_type/user_id`（Customer 含む）・`resource_type/resource_id` | **書き換え禁止**。監査ログの完全性が最優先。A の過去操作は A の id のまま残し、`customer_merges` を辿れば B に接続できる。03§4「ログイン履歴＝AuditLog の絞り込みビュー」とも整合 |
| CSV エクスポート履歴等の運用データ（`csv_exports.requested_by_id`→users） | 実行者は `users` | 対象外（顧客に紐づかない） |
| 申込（`applications.customer_id`） | nullable FK nullify | **移管する**（§1-2 手順4。R3 で追加されたテーブル。Laravel設計時と同じ扱い） |

原則: **「業務の実体（店舗・案件・申込）は移管、事実の記録（通知送信・監査・ログイン）は凍結」**。

---

## 5. セキュリティ考慮

1. **推測耐性**: 60bit ランダム（Base32 12 文字）＋ DB はハッシュ保存＋ワンタイム＋試行 5 回＋`rack-attack` throttle（`config/initializers/rack_attack.rb` に `mypage/customer_merges` POST を B アカウント（`warden` の customer id または IP）単位で 10 回/時 など追加）。5 回試行では 2^60 空間は事実上ゼロヒット。キー平文はメール本文にのみ存在し、画面・ログ・DB に残さない（`config/initializers/filter_parameter_logging.rb` に `merge_key` を追加）。
2. **なりすまし統合の防止（メール所有確認）**: キーを**Aの登録メールアドレス以外に送れない**ことが本設計の核。攻撃者が A のセッションを一時的に奪ってもキーは A のメールボックスに届くため、メール所有まで奪わない限り統合を完遂できない。宛先の自由入力欄は設けない。`customers.email` が nil の顧客（R3 の申込経由で email 無しで作成されうる）は発行不可としエラー表示。
3. **B 側の確定操作**: 確認画面（A の顧客番号＋マスク済み名称/メール、移管件数の提示）→ B のパスワード再入力（`current_customer.valid_password?`）→ 実行。CSRF は Rails 標準（`protect_from_forgery`）。B セッション奪取単体でも A のキーが無ければ何もできない（双方向の担保）。
4. **事後検知**: 完了メールを **A の旧アドレスと B の両方**に送る。身に覚えのない統合を A 本人が検知できる（パスワード変更通知と同じ発想）。`customer_merges` に IP/UA を残し調査可能にする。
5. **発行側の濫用防止**: 発行は 3 回/日（A 単位）に制限（rack-attack + `customer_merge_keys` の直近作成件数）。発行のたびに旧キー失効＋発行通知メール。
6. **実行時再検証**: A≠B、両者 active、キー諸条件をトランザクション内で再チェック（TOCTOU 回避）。
7. **セッション後始末**: 統合成立で A の `encrypted_password` を空にし（Devise `authenticatable_salt` 変化で全セッション失効）、OTP 状態もクリア。
8. **認可レイヤー**: mypage section は決定C により「認証済み顧客なら通れる」固定運用だが、`Mypage::CustomerMergesController` 内で `current_customer` 以外の顧客レコード（A）を操作するため、Pundit の `CustomerMergePolicy#create?`（`record.target == user`）と `Form`/`Admin` からの到達不能（ルート自体を mypage 配下にのみ定義）で二重に守る。

---

## 6. 移行時名寄せ（P5-5 = R7 / legacy-research/09）との関係整理

**別物である点:**

| | P4-4（本機能・R6） | P5-5 の名寄せ（09 §C-3/C-5・R7） |
|---|---|---|
| 目的 | 稼働後、同一実顧客の複数アカウントを顧客自身の意思で統合 | 移行 ETL 時に、手入力文字列（掲示板投稿者 `FT浅賀` 等）や表記ゆれをユーザ/顧客 ID に突合 |
| 主体 | 顧客（マイページ・セルフサービス） | 開発側バッチ（名寄せ表＋目視判断。`name-matching-process.md`） |
| 機構 | 統合キー＋トランザクション移管＋履歴 | 名寄せ表（表記→ID 対応表）＋未一致は「不明ユーザ」で保持 |
| 実行タイミング | 稼働後いつでも | カットオーバー前の一回性作業 |

**接続点（共用できる部分）:**

1. **移行時の「怪しい重複顧客」の受け皿になる**: 09 の方針は「自動修正はしない・検知してフラグ」。移行時に同一実顧客の疑いがあっても機械的に束ねず**別レコードのまま投入**し、稼働後に本機能（＋将来の管理者主導マージ）で統合する、という逃げ道ができる。移行名寄せの判断コストと誤マージリスクを下げる。
2. **`CustomerMergeService` の再利用**: 移管本体を UI から分離しておく（§1-1）ことで、移行後クリーンアップとして管理者が rake タスク（`customer:merge[source_id,target_id]`）／管理画面から同じ移管ロジックを叩ける。移管対象テーブルの追加（R5 以降に増える契約・決済系 `payment_transactions` 等が `customer_id` を持つ場合）も `CustomerMergeService::MOVABLE_ASSOCIATIONS` 1 箇所の修正で済む。**R5 のスキーマ設計時に「顧客 FK を持つ新テーブルは本サービスの移管対象に追加する」ことをチェック項目に入れる。**
3. **`customer_merges` 履歴の共用**: 管理者主導マージも同じ履歴テーブルに記録（`performed_by_type='User'`）すれば「顧客 ID の系譜」が一元化され、移行後の照会（旧システム顧客コード→現顧客）にも使える。
4. **PII ルールの準用**: 移行名寄せ表の PII 取扱（`pii-handling-rules.md` §4-2）と同様、`source_snapshot` の閲覧権限・保持期間を管理する。

非共用: 表記ゆれ正規化（半角カナ・全角化等）は ETL 固有であり本機能には持ち込まない。

---

## 7. 実装タスクへの対応表

| P4-4 タスク（Rails版 R6） | 本書の該当節 | Rails 実装物（案） |
|---|---|---|
| a 一時統合キーのテーブル | §2-1 | migration `create_customer_merge_keys` / `CustomerMergeKey` モデル |
| b 発行 UI＋メール | §1-1 ①② / §5-1,2,5 | `Mypage::MergeKeysController#create` / `CustomerMergeMailer#key_issued` / rack-attack |
| c 入力検証 UI | §1-1 ③④⑤ / §5-3 | `Mypage::CustomerMergesController#new/confirm/create`（ERB + Turbo） |
| d 移管処理（トランザクション） | §1-2 | `CustomerMergeService`（`app/services/`） |
| e 統合履歴 | §2-2 | migration `create_customer_merges` / `CustomerMerge` モデル / `Admin::CustomerMergesController`（index/show）/ `CustomerMergePolicy` |
| f 統合対象外データ | §4 | （設計のみ。コード変更なし） |
| Q-11〜13（D-12 決定済み） | §3 | `config/customer_merge.yml` / rake `customer:unmerge` |
| 定期削除 | §2-1 | `config/recurring.yml` に `CustomerMergeKey.prune_stale!` |

備考: P4-9（マイページ機能拡充。R6）でマイページのナビゲーション・画面骨格が変わる予定のため、発行/入力 UI の配置は P4-9 の画面設計と同時に確定する（development-plan の「P4-9 と併せて設計」に対応）。

## 8. request spec 必須事項（04 R6・T-1 負債対策）

04 R6 本文の要求（2026-08-15追記）を満たすため、以下を **実装と同時に** `spec/requests/mypage/customer_merges_spec.rb` / `spec/services/customer_merge_service_spec.rb` に置く（認可テストハーネスは既定=実認可）。

| # | 検証内容 | 対応節 |
|---|---|---|
| S-1 | 行ロック: A/B を `lock` した状態で別スレッドから A の `Customer#lock!` 更新が待たされ、コミット後に反映される（`spec/models/customer_spec.rb` の採番並行 spec と同型でスレッド実行） | §1-2 手順1 |
| S-2 | TOCTOU 再検証: 確認画面表示後に A を withdrawn にしてから `#create` を叩くと失敗し、移管もキー消費も起きない | §1-2 手順2 / §5-6 |
| S-3 | ワンタイム消費: 同一キーで `#create` を並行 2 本（またはリトライ）投げたとき、成功は 1 本のみで `customer_merges` は 1 行、`consumed_at` は 1 回だけ刻まれる | §1-2 二重送信 |
| S-4 | 代理店またぎ検知: `agency_id` が異なる A/B を統合すると `customer_merges.source_agency_id != target_agency_id` として記録され、staff の一覧で検知できる。代理店ユーザは他代理店の履歴を参照できない（`policy_scope`） | §1-2 注意点 / §2-2 |
| S-5 | 例外時ロールバック: 手順 4〜7 の途中で例外を起こすと stores/orders/applications の `customer_id`・A の status・キーの `consumed_at` がすべて元のまま | §1-2 失敗点 |
| S-6 | 退会化後のログイン遮断: A の旧パスワード／旧セッションで mypage にアクセスできない。email unique が解放され B が A の旧 email を設定できる | §3 Q-12 |
| S-7 | 認可: `Form`/`Admin` セッションから mypage の統合ルートに到達できない。B 以外の顧客のキー消費（別顧客のセッション）で失敗する | §5-8 |
| S-8 | 監査: 統合成功で `AuditLog`（action=customer_merged）が 1 件・A の `status` 変更が Auditable で 1 件記録される | §1-2 手順7 |

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-26 | 初版（設計案）。フロー・データモデル・Q-11〜13 推奨・対象外データ方針・P5-5 との関係を整理 |
| 2026-08-19 | Rails版改訂（R6・未実装）。§0 を Rails 現行実装（Customer/Store/Order/Application・AuditLog・OtpAuthenticatable・Pundit AgencyScoped）で再突合。`lockForUpdate`/`DB::transaction`/Eloquent/Job/Vue/artisan/throttle を `lock`/`ActiveRecord::Base.transaction`/`update_all`/Solid Queue/Hotwire/rake/rack-attack へ読み替え。`remember_token` 不在・`encrypted_password` 空文字による無効化・Devise セッション失効機構を反映。代理店またぎ時の Order/Store スコープ非対称を追記。§8（request spec 必須事項 S-1〜S-8）を新設 |
