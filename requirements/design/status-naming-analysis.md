# Q-B 解消案: 「顧客ステータス」の呼称と customer_statuses / order_statuses の関係整理

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/status-naming-analysis.md）を
> brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。フェーズ対応: **R2**（CustomerStatus / OrderStatus マスタ・
> `SystemManagedStatus` concern・`StatusSeeder`。実装済み）／R4（InquiryStatus。実装済み・本書の対象外だが同型）／
> R5（契約ワークフロー状態機械＝旧 P3-4）／R6（ステータス遷移バリデーション）／R7（旧「顧客ステータス」→ `orders.status` マッピング）。
> 突合日 2026-08-19（`app/models/customer_status.rb`・`order_status.rb`・`concerns/system_managed_status.rb`・`app/services/status_seeder.rb`・
> `app/views/admin/customer_statuses/`・`order_statuses/`・`customers/`・`orders/`・`db/schema.rb`）。
>
> **ステータス: 決定済み（D-8・2026-07-26 案A承認。`development-plan.md` §8 Q-B ✅）＋ 実装適用状況の突合済み（2026-08-19）**
> 対象: `development-plan.md` §8 Q-B。P3-4（案件ステータス状態機械 → **R5**）の前提整理。
> 本書は分析と提案・突合のみで、コード・マイグレーション・ビューの変更は行っていない（ビュー修正は 04 R2 追加タスク）。
>
> **突合結果の要点（§0-1 に詳細）**: 案A は `order_statuses` 側（マスタ画面「案件ステータス」）には適用済みだが、
> `customer_statuses` 側は管理画面（`app/views/admin/customer_statuses/*.html.erb`）・モデル/コントローラのコメント・マイグレーションコメントが
> 「顧客ステータス」のまま＝**中途半端な適用状態**（review-05 §1-2・04 R2追加タスク・04 リスク6 の指摘どおり）。修正対象ファイルは §4 に列挙。

---

## 0. 結論（先に要点）

- **ねじれの正体**: 現行システム（Bridge/BridgePlus）と業務資料が「**顧客ステータス**」と呼ぶ35値は、
  新実装では**案件側**（`orders.status` ＝ `order_statuses` マスタ）に入っている。
  一方、新実装には**別系列の8値**を持つ `customer_statuses`（申込受付〜退会済み）が存在し、
  管理画面では「**顧客ステータス**」の名でこちらが表示される。
  つまり**同じ「顧客ステータス」という語が、旧＝案件35値／新＝申込8値の全く別物を指す**。
- さらに同じ `orders.status` が、画面によって「**案件ステータス**」（マスタ管理画面）、
  「**作業ステータス**」（Laravel時代の案件編集・詳細画面）、「**顧客ステータス**」（Column.md・レガシー資料）と
  **3通りの表示名**で呼ばれており、テーブル名（`order_statuses`）を含めると呼称は4系統ある。
  （Rails版の案件フォーム・詳細では項目名が単に「ステータス」で、「作業ステータス」表記は消えている。§1-2）
- **推奨（→ D-8 として採用済み）**: DBスキーマは変えず（テーブル名は正しい設計）、**用語を3語に確定して表示名・文書を統一**する。
  - `orders.status` / `order_statuses` → 正式名「**案件ステータス**」（旧称「顧客ステータス」は移行文脈のみで併記）
  - `customers.status` / `customer_statuses` → 正式名「**申込ステータス**」（画面・文書から「顧客ステータス」表記を排除）
  - `orders.contract_status` → 「契約ステータス」（現状どおり・変更なし）

### 0-1. Rails 実装への適用状況（2026-08-19 突合）

| 実体 | 案A 正式名 | 適用済み箇所 | 未適用（旧称・無印のまま）箇所 |
|---|---|---|---|
| `orders.status` / `OrderStatus` | 案件ステータス | マスタ画面 `app/views/admin/order_statuses/index.html.erb`（h1「案件ステータス」）・`new.html.erb`（「案件ステータスの新規作成」）・`edit.html.erb`（「案件ステータスの編集」）、`app/models/order_status.rb` 1行目コメント、`app/controllers/admin/order_statuses_controller.rb` 1行目コメント、`spec/factories/order_statuses.rb`（label 連番「案件ステータスn」） | 案件フォーム `app/views/admin/orders/_form.html.erb` 44行目 `f.label :status, "ステータス"`、案件詳細 `orders/show.html.erb` 9行目「ステータス」、案件一覧 `orders/index.html.erb` 23行目 th「ステータス」、マイページ `app/views/mypage/dashboard/index.html.erb` 7行目 th「状態」（いずれも「案件ステータス」と明示していない＝誤りではないが統一漏れ）。`requirements/design/Column.md` 698行目「顧客ステータス」（別担当ファイル） |
| `customers.status` / `CustomerStatus` | 申込ステータス | **なし**（申込ステータス表記はコード・画面のどこにも無い） | マスタ画面 `app/views/admin/customer_statuses/index.html.erb` 2行目 h1「顧客ステータス」・`new.html.erb` 2行目「顧客ステータスの新規作成」・`edit.html.erb` 2行目「顧客ステータスの編集」、`app/models/customer_status.rb` 1行目コメント「顧客ステータスマスタ」、`app/controllers/admin/customer_statuses_controller.rb` 1行目コメント「顧客ステータスマスタ管理」、`db/migrate/20260815140002_create_customer_statuses.rb` 3行目コメント「顧客ステータスのDB管理化」、`db/seeds.rb` 4行目コメント「顧客/案件ステータスマスタ」、顧客フォーム `app/views/admin/customers/_form.html.erb` 23行目 `f.label :status, "ステータス"`、顧客詳細 `customers/show.html.erb` 6行目「ステータス」、顧客一覧 `customers/index.html.erb` 23行目 th「ステータス」。`requirements/design/Column.md` 460行目「ワークフローステータス」（別担当ファイル） |
| `orders.contract_status` | 契約ステータス | `app/views/admin/orders/_form.html.erb` 51行目「契約ステータス」 | — |

補足: 一斉通知（`Notification#customer_recipients`）の `filter_params["status"]` は申込8値側（`customers.status`）で絞り込む実装だが、
フィルタ入力 UI 自体が `app/views/admin/notifications/_form.html.erb` に未配置のため、現時点で「ラベル修正」対象は無い
（UI 追加時に「申込ステータス」と明示すること）。管理画面の左メニュー（サイドバー）は Rails 版に存在せず（`app/views/admin/dashboard/index.html.erb` の nav は
ロール/権限/ログイン履歴/IP許可のみ）、Laravel `AppSidebar.vue` 相当の修正箇所は無い。

---

## 1. 現状整理: 2つのステータステーブルの実定義・値・参照元

（Laravel時点の調査結果を Rails 実装（R2）へ読み替え。Laravel 側のファイル名は「移行元」として括弧内に残す）

### 1-1. customer_statuses（顧客テーブル側のマスタ）

| 項目 | 内容 | コード根拠（Rails） |
|---|---|---|
| テーブル定義 | `code`(UNIQUE) / `label` / `sort_order` / `is_active` / `is_system` / created_by_id・updated_by_id。UUID PK（`gen_random_uuid()`） | `db/schema.rb` `create_table "customer_statuses"`（`db/migrate/20260815140002_create_customer_statuses.rb`。移行元 `2026_06_12_000001_create_customer_statuses_table.php`） |
| マイグレーションコメント | 「顧客ステータスのDB管理化」（Rails）。移行元 Laravel は「**顧客の申込ステータス**を管理する専用マスタテーブル」 | 同上 3行目 |
| モデル | `CustomerStatus`（`include SystemManagedStatus`）。定数 `CODE_APPLIED = "applied"` / `CODE_WITHDRAWN = "withdrawn"`。`has_many :customers, foreign_key: :status, primary_key: :code` | `app/models/customer_status.rb` |
| 共通 concern | `SystemManagedStatus`（`app/models/concerns/system_managed_status.rb`）: `code` presence/uniqueness(グローバル)/max100、`label` presence、`is_system` 行の code 変更禁止・削除禁止、`active`/`ordered` スコープ、`TracksUser`＋`Auditable` を内包 | 同上 |
| シード値（8値） | `applied` 申込受付（is_system） / `needs_correction` 不備確認中 / `returned` 差戻し / `confirm_call_pending` 確認コール待ち / `confirm_call_done` 確認コール済 / `needs_reconfirmation` 再確認要 / `contracted` 契約確定 / `withdrawn` 退会済み（is_system）。**Laravel シードとは code 識別子が異なる**（旧: reviewing / awaiting_call / call_done / re_confirm / confirmed。ラベルは同一）。is_system は先頭・末尾の2値のみ（Laravel は8値すべて is_system） | `app/services/status_seeder.rb` `CUSTOMER_STATUSES`（`db/seeds.rb` から `StatusSeeder.call`。spec では `seed_status_catalog: true`） |

**参照元（`customers.status` がこのマスタの code を保持）**:

| 参照箇所 | 内容 | ファイル（Rails） |
|---|---|---|
| カラム定義 | `customers.status` string(50) NOT NULL default `"applied"`、index あり | `db/schema.rb`（`app/models/customer.rb` アノテーション 63行目） |
| モデル | `Customer#assign_default_status`（`CustomerStatus::CODE_APPLIED`）、`validate :status_must_exist_in_customer_statuses`、`scope :active`（`status != withdrawn`）、Devise `active_for_authentication?` も withdrawn を除外 | `app/models/customer.rb` 116-122, 152-170行目 |
| 顧客CRUD | フォームは `CustomerStatus.ordered` の `collection_select`（label 表示・code 保存）、一覧/詳細は code をそのまま表示（label 変換なし） | `app/controllers/admin/customers_controller.rb`（`customer_params` に `:status`）／`app/views/admin/customers/_form.html.erb` 23行目・`index.html.erb` 32行目・`show.html.erb` 6行目 |
| 一斉通知の絞り込み | 配信対象を `customers.status`（`filter_params["status"]`）で絞る（UI 未配置） | `app/models/notification.rb` `customer_recipients` |
| マスタCRUD | `/admin/customer_statuses`（is_system は削除・code変更不可） | `app/controllers/admin/customer_statuses_controller.rb` / `config/routes.rb` 84行目 / `app/policies/customer_status_policy.rb` |
| 画面 | マスタ画面タイトル「**顧客ステータス**」（index/new/edit） | `app/views/admin/customer_statuses/index.html.erb` 2行目ほか（§0-1） |
| 監査 | `Auditable::TRACKED_FIELDS["Customer"]` に `status`、`["CustomerStatus"]` に code/label/is_active/is_system | `app/models/concerns/auditable.rb` |
| テスト | `spec/models/customer_status_spec.rb`、`spec/requests/admin/master_data_spec.rb`（customer_statuses 節）、`spec/factories/customer_statuses.rb` | — |

### 1-2. order_statuses（案件テーブル側のマスタ）

| 項目 | 内容 | コード根拠（Rails） |
|---|---|---|
| テーブル定義 | 構造は customer_statuses と同型（`code` UNIQUE） | `db/schema.rb` `create_table "order_statuses"`（`db/migrate/20260815140003_create_order_statuses.rb`。移行元 `2026_06_12_000003_create_order_statuses_table.php`） |
| マイグレーションコメント | 「案件ステータスのDB管理化」「code は orders.status に格納される実値」 | 同上 3-4行目 |
| モデル | `OrderStatus`（`include SystemManagedStatus`）。定数 `CODE_ORDERED = "0:受注"`。`has_many :orders, foreign_key: :status, primary_key: :code` | `app/models/order_status.rb` |
| シード値 | **5値のみ**: `0:受注`（is_system）/ `10:作業進行中` / `21:解約` / `22:強制解約` / `100:CLOSE`。**code＝「番号:日本語ラベル」の複合文字列**（レガシー実値そのまま）。Laravel シードの35値（`0:受注`〜`16:完了`、`20`〜`22`、`23〜34:解約処理待ち（月度別12）`、`95:強制解約（不正）`）は**未投入**（「運用開始後に権限管理UIから追加する前提」と StatusSeeder コメントに明記） | `app/services/status_seeder.rb` `ORDER_STATUSES` |

**参照元（`orders.status` がこのマスタの code を保持）**:

| 参照箇所 | 内容 | ファイル（Rails） |
|---|---|---|
| カラム定義 | `orders.status` string(50) NOT NULL default `"0:受注"`、index あり。※Column.md の説明文が「**顧客ステータス**」 | `db/schema.rb`（`app/models/order.rb` アノテーション 95行目）／`requirements/design/Column.md` 698行目 |
| モデル | `Order#assign_default_status`（`OrderStatus::CODE_ORDERED`）、`validate :status_must_exist_in_order_statuses`。別に `contract_status`（string(10)・長さ検証のみ・値の定数リスト無し）と `consent_status`（string(20)）あり | `app/models/order.rb` 162-172, 184行目 |
| 案件CRUD | フォームは `OrderStatus.ordered` の `collection_select`（label 表示・code 保存）、一覧/詳細は code をそのまま表示 | `app/controllers/admin/orders_controller.rb`／`app/views/admin/orders/_form.html.erb` 44行目・`index.html.erb` 32行目・`show.html.erb` 9行目 |
| マスタCRUD | `/admin/order_statuses` | `app/controllers/admin/order_statuses_controller.rb` / `config/routes.rb` 85行目 / `app/policies/order_status_policy.rb` |
| 画面（マスタ） | 画面タイトル「**案件ステータス**」（index/new/edit）＝案A適用済み | `app/views/admin/order_statuses/index.html.erb` 2行目ほか |
| 画面（案件） | フォーム・詳細・一覧の項目名は「**ステータス**」（Laravel時代の「作業ステータス」表記は Rails 版に無い）。隣に「契約ステータス」 | `app/views/admin/orders/_form.html.erb` 44, 51行目 / `show.html.erb` 9行目 |
| マイページ | 顧客向け案件一覧の列名「状態」 | `app/views/mypage/dashboard/index.html.erb` 7行目 |
| 監査 | `Auditable::TRACKED_FIELDS["Order"]` に `status` `contract_status`、`["OrderStatus"]` に code/label/is_active/is_system | `app/models/concerns/auditable.rb` |
| 申込フォーム | `FormField#target_column` のホワイトリストから Order/Customer の `status` を除外済み（R3 追補 `06d8693`）＝フォームビルダー経由でステータスを直接書けない | `app/models/form_field.rb` |

### 1-3. 補足: 案件にはステータス系カラムが3本ある

`orders` には `status`（order_statuses 参照）、`contract_status`（有効/解約/停止相当。Rails 版では長さ検証のみで値リスト定数なし）、
`consent_status`（同意書類系）が並存する（`app/models/order.rb` 46, 49, 95行目）。Q-B の対象は `status` のみ。

### 1-4. 補足（2026-08-19）: R4 で追加された第3のステータスマスタ `inquiry_statuses`

R4（決定D-11）で `InquiryStatus`（`inquiry_statuses`: category 単位で code 一意）が追加された（`board-implementation-options.md` §0）。
`SystemManagedStatus` はグローバル一意を前提にしているため concern は流用せず個別実装。呼称は「問い合わせステータス」で、
本書の3語（案件/申込/契約）と衝突しない。Q-B の対象外だが、用語集（§4-2）には4語目として載せる。

---

## 2. ねじれの構造: どこで何と呼ばれているか

### 2-1. 現行システム（Bridge/BridgePlus）での「顧客ステータス」

レガシーの業務・資料では「顧客ステータス」＝**受注案件の進行状態（35値）**である。

- 精査資料の名称自体が「顧客ステータス37＋掲示板4種」（`legacy-research/00-index.md` 65行目）
- 編集権限の階層制御が「**顧客ステータス**：『16:完了』以降は第二階層以下不可」
  （`legacy-research/05-legacy-spec-fields.md` 22, 30行目）→ 値は明らかに案件進行の値
- 移行マッピングでレガシー項目「**59 顧客ステータス**」→ 新 `orders.status`
  （`legacy-research/11-order-field-mapping.md` 57, 73行目。同書は `jasmin_orders` 表記のまま＝決定D の prefix 除去で `orders` に読み替え）
- `business-flow-analysis.md` §3-2 が既にこの不整合を指摘（103-110行目）：
  「実務で『顧客ステータス』と呼ぶ値が、実装では**案件ステータス**に入っている」

背景: レガシーは顧客≒案件が1:1に近い運用だったため「顧客の状態」と呼んでいたが、
新設計は顧客(`customers`) 1 : N 案件(`orders`)に正規化したので、
進行状態は案件側に置くのが正しい。**テーブル設計は正しく、呼称だけが旧世界の語のまま**。

### 2-2. 呼称マトリクス（ねじれの一覧）

| 実体 | テーブル名 | 業務用語（レガシー資料） | 設計書（Column.md） | 画面表示名（Rails版 2026-08-19） |
|---|---|---|---|---|
| `orders.status`（35値想定・現シード5値） | `order_statuses` | **顧客ステータス** | **顧客ステータス**（698行目） | マスタ画面「**案件ステータス**」／案件フォーム・詳細・一覧「ステータス」／マイページ「状態」 |
| `customers.status`（8値） | `customer_statuses` | （対応概念なし＝新設） | 「ワークフローステータス」（460行目） | マスタ画面「**顧客ステータス**」／顧客フォーム・詳細・一覧「ステータス」 |

ねじれは2層ある:

1. **語の衝突（重大）**: 業務側の「顧客ステータス」（＝案件35値）と、新実装の管理画面
   「顧客ステータス」マスタ（＝申込8値）が**同名で別物**。導入時、現場が「顧客ステータスを変更したい」と
   言うと管理画面の別マスタに誘導される。一斉通知の絞り込み（`Notification#customer_recipients`）も
   申込8値側なので、「顧客ステータス＝35値」の感覚で使うと配信対象を誤る。**Rails 版でもこの層は未解消**（§0-1）。
2. **表示名の揺れ（中）**: 同一カラム `orders.status` が「案件ステータス」（マスタ）「ステータス」（案件画面）「状態」（マイページ）
   「顧客ステータス（設計書）」と画面・文書間で不一致。Laravel 時代の「作業ステータス」は Rails 版で消えたが、
   案件画面側が「案件ステータス」と明示していないため、R5 で状態機械・遷移UI・通知文言を作ると
   この揺れがそのままユーザー向け文言と監査ログ（`AuditLog` は `status` キーで記録）に固定される。

---

## 3. 整理案

### 3-1. 推奨案: 「スキーマ据え置き・用語3語確定・表示統一」（案A）**【D-8 採用済み】**

**DB・モデル・ルートは変更しない。** 決めるのは正式用語と表示名だけ。

| 実体 | 正式名称（確定） | 英語系識別子（現状維持） | 備考 |
|---|---|---|---|
| `orders.status` / `order_statuses` | **案件ステータス** | order_status / `OrderStatus` | レガシー資料引用・移行文書でのみ「（旧称: 顧客ステータス）」を併記 |
| `customers.status` / `customer_statuses` | **申込ステータス** | customer_status / `CustomerStatus` | 「顧客ステータス」の名は**使用禁止語**にする |
| `orders.contract_status` | 契約ステータス | contract_status | 変更なし |

根拠:

1. **テーブルの置き場所は正しい**。35値は案件の進行状態であり `orders` 側にあるべきで、
   顧客1:N案件の新モデルでは「顧客ステータス」の名を35値に戻す方が設計として退行する。
   直すべきは器ではなく語。
2. **customer_statuses の実体は申込〜契約〜退会のライフサイクル**（applied→…→contracted / withdrawn）。
   移行元マイグレーションコメント自身が「顧客の**申込ステータス**」と書いており、「申込ステータス」は実装意図とも一致する。
   これにより業務語「顧客ステータス」との衝突が語彙レベルで消える。
3. **「作業ステータス」は廃止して「案件ステータス」に寄せる**。35値には作業以外
   （キャンセル・解約・CLOSE）が含まれ「作業」は不正確。マスタ画面が既に「案件ステータス」であり、
   統一コストが最小。（Rails 版では「作業ステータス」表記は既に無い。案件画面の「ステータス」を「案件ステータス」に明示するのみ）
4. **リネーム不要＝R5 を止めない**。案Aは文書と ERB 表示文字列の修正のみで、
   マイグレーション・ルート・API契約に触れないため即日確定できる。

段階案（DB名まで揃えたい場合のオプション・案A'）:

- Phase 1（今すぐ・R5前）: 案Aの用語確定＋表示・文書統一。**D-8 で確定済み。表示統一は `customer_statuses` 側が未着手（04 R2 追加タスク）**。
- Phase 2（任意・R5以降の落ち着いた時期）: `customer_statuses` → `application_statuses`
  （モデル `CustomerStatus` → `ApplicationStatus`、ルート `/admin/customer_statuses` →
  `/admin/application_statuses`）へリネームし、識別子も「申込ステータス」に一致させる。
  ただし**移行前でデータ資産が薄い今やらないなら、稼働後はやらない**（リネーム益 < 回帰リスク）。
  Phase 2 は「やらない」で確定しても案Aは成立する。**注意（Rails版）**: 既に `Application` モデル（申込フォームの進行状態。`applications` テーブル・R3）が存在するため、
  `ApplicationStatus` という名は「Application モデルのステータス」と誤読される。Phase 2 を行うなら別名（例: `CustomerWorkflowStatus`）を再検討すること。

### 3-2. 非推奨とした代替案

| 案 | 内容 | 不採用理由 |
|---|---|---|
| 案B: 業務語に合わせ `order_statuses` を「顧客ステータス」と表示 | 現行ユーザーの語感を優先 | 顧客1:N案件の新モデルと矛盾。1顧客に複数案件が付いた瞬間「顧客のステータスがどれか」が破綻。customer_statuses との衝突も未解決 |
| 案C: customer_statuses を廃止し `customers.status` を有効/退会の2値等に縮退 | 申込8値は案件側の前半（不備チェック・確認コール）と意味が重複しているため | 影響が大きい（一斉通知フィルタ・顧客CRUD・`Customer.active`/Devise 認証可否・テスト）。重複の当否は R5 の状態機械設計で判断すべきで、Q-B（呼称問題)の解決を人質にしない。§5 の残論点へ送る |

### 3-3. P3-4（案件ステータス状態機械 → R5）の前に決めるべき理由

1. **R5 は35値の統廃合を含む**（`legacy-research/03` §3: 受注削除・3値統合・95削除）。
   統廃合後のマスタ整備（現シードは5値のみ）・遷移定義・遷移時必須入力（同 §2-1）を実装する際、
   ドメイン語彙（クラス名・イベント名・通知文言・監査ログ表示）が「案件/作業/顧客」で
   揺れたまま書かれると、後から直すのはコード全面に及ぶ。
2. **P3-2-e（決済状態→業務ステータス連動）が状態機械の後続**（R5）。
   決済側から参照する「業務ステータス」がどちらのテーブルか、命名で自明になっている必要がある。
3. **Q-C（掲示板4種）・通知マトリクス（Q-21）が同じ語彙に乗る**。掲示板はステータス駆動
   （`legacy-research/03` §1）であり、R4 で `InquiryStatus`（問い合わせステータス）が第3のマスタとして加わった今、
   3語＋「問い合わせステータス」の使い分けを確定しておく必要がある。
4. **データ移行の旧→新マッピング**（`release-readiness.md` B-6・R7）で「レガシー59 顧客ステータス →
   新・案件ステータス（`orders.status`）」という対訳を確定させないと、移行手順書・現場向け説明資料が書けない。

---

## 4. 影響範囲（案A採用時に変更が必要なファイル）

コード挙動の変更はゼロ。**表示文字列と文書のみ**（Phase 1）。Rails 版の実ファイルで 2026-08-19 に再確認した一覧（§0-1 の根拠）。
本書では修正を行わない（04 R2 追加タスクとして実施）。

### 4-1. ビュー（表示名の統一）— customer_statuses 側（未適用・要修正）

| ファイル | 行 | 現状 | 変更内容 |
|---|---|---|---|
| `app/views/admin/customer_statuses/index.html.erb` | 2 | `<h1>顧客ステータス</h1>` | 「申込ステータス」 |
| `app/views/admin/customer_statuses/new.html.erb` | 2 | 「顧客ステータスの新規作成」 | 「申込ステータスの新規作成」 |
| `app/views/admin/customer_statuses/edit.html.erb` | 2 | 「顧客ステータスの編集」 | 「申込ステータスの編集」 |
| `app/views/admin/customer_statuses/show.html.erb` | — | h1 は label のみ（呼称なし） | 変更不要（パンくず等を足すなら「申込ステータス」） |
| `app/views/admin/customers/_form.html.erb` | 23 | `f.label :status, "ステータス"` | 「申込ステータス」（誤解防止のため明示） |
| `app/views/admin/customers/show.html.erb` | 6 | `<dt>ステータス</dt>` | 「申込ステータス」（併せて code → `CustomerStatus` label 表示を検討） |
| `app/views/admin/customers/index.html.erb` | 23 | `<th>ステータス</th>` | 「申込ステータス」 |
| `app/views/admin/notifications/_form.html.erb` | — | フィルタ UI 未配置 | フィルタ（`filter_params[status]`）UI を追加する際はラベルを「申込ステータス」にする |

### 4-1b. ビュー（表示名の統一）— order_statuses 側（マスタ画面は適用済み・案件画面は明示漏れ）

| ファイル | 行 | 現状 | 変更内容 |
|---|---|---|---|
| `app/views/admin/order_statuses/{index,new,edit}.html.erb` | 2 | 「案件ステータス」 | 変更不要（適用済み） |
| `app/views/admin/orders/_form.html.erb` | 44 | `f.label :status, "ステータス"` | 「案件ステータス」（51行目「契約ステータス」と並列で明示） |
| `app/views/admin/orders/show.html.erb` | 9 | `<dt>ステータス</dt>` | 「案件ステータス」 |
| `app/views/admin/orders/index.html.erb` | 23 | `<th>ステータス</th>` | 「案件ステータス」 |
| `app/views/mypage/dashboard/index.html.erb` | 7 | `<th>状態</th>` | 「案件ステータス」（顧客向け文言は業務確認。「状態」のままでも可） |

### 4-2. 設計文書

| ファイル | 変更内容 | 状態 |
|---|---|---|
| `requirements/design/Column.md`（698行目） | `orders.status` の説明「顧客ステータス」→「案件ステータス（旧称: 顧客ステータス）」 | 未反映（別担当の改訂で対応） |
| `requirements/design/Column.md`（460行目） | `customers.status` の説明「ワークフローステータス」→「申込ステータス」 | 未反映（同上） |
| `requirements/design/business-flow-analysis.md` §3-2・§11 | Q-B 解消の旨と本書への参照を追記 | 要確認 |
| `requirements/development-plan.md` §8 Q-B | ✅ D-8 決定済み（2026-07-26） | 反映済み |
| `requirements/design/04-rails-implementation-plan.md` | R2 追加タスク「Q-B の実装が中途半端」・リスク6・次のアクション5 に記載あり。**案Aを正式決定として本文に記録**し、本書 §4-1/4-1b を修正ファイル一覧として参照する | 一部反映（決定記録の明記は未） |
| `requirements/design/legacy-research/10・11` ほか移行系 | 「59 顧客ステータス → 案件ステータス（`orders.status`）」の対訳を明記 | 未反映（R7 着手時） |
| 用語集（新設推奨） | 「案件ステータス／申込ステータス／契約ステータス／問い合わせステータス（R4 追加）」の4語定義。`requirements/design/` 配下 or basic-design.md 冒頭 | 未作成 |

### 4-3. コード内コメント（任意・低優先）

| ファイル | 行 | 変更内容 |
|---|---|---|
| `app/models/customer_status.rb` | 1 | 「顧客ステータスマスタ」→「申込ステータスマスタ（旧称・使用禁止語: 顧客ステータス）」 |
| `app/controllers/admin/customer_statuses_controller.rb` | 1 | 「顧客ステータスマスタ管理」→「申込ステータスマスタ管理」 |
| `db/migrate/20260815140002_create_customer_statuses.rb` | 3 | 「顧客ステータスのDB管理化」→「申込ステータス（customer_statuses）のDB管理化」（適用済み DB への再実行はないためコメント修正のみ・schema 変更なし） |
| `db/seeds.rb` | 4 | 「顧客/案件ステータスマスタ」→「申込/案件ステータスマスタ」 |
| `app/models/customer.rb` | status 周辺 | doc コメントに「申込ステータス」の正式名を追記 |
| `spec/factories/customer_statuses.rb` | 29 | label 連番「ステータスn」→「申込ステータスn」（任意。`order_statuses` factory は「案件ステータスn」で統一済み） |

### 4-4. Phase 2（テーブルリネームまでやる場合のみ）

`db/migrate/`（rename_table＋新規1本）、`app/models/customer_status.rb`、`app/policies/customer_status_policy.rb`、
`app/controllers/admin/customer_statuses_controller.rb`、`config/routes.rb`（84行目）、
`app/models/customer.rb`・`app/models/notification.rb`・`app/services/status_seeder.rb` の参照、
`app/views/admin/customer_statuses/`（ディレクトリごと）、`app/models/concerns/auditable.rb`（`TRACKED_FIELDS` キー）、
`spec/factories/customer_statuses.rb`・`spec/models/customer_status_spec.rb`・`spec/requests/admin/master_data_spec.rb`、
権限カタログ（`SystemPermission` は起動時に `SystemPermissionSyncService` がルートから再同期するが、`RoleSeeder` のコントローラ名指定と
既存ロールへの権限付与は要更新）。
※前述のとおり Phase 2 は「やらない」判断も可。§3-1 の `ApplicationStatus` 命名衝突にも注意。

---

## 5. 未決のまま残る論点

1. **申込8値と案件35値の意味重複（案C送り）**: `customer_statuses` の
   needs_correction/returned/confirm_call_pending/confirm_call_done は案件35値の前半（不備チェック・確認コール）と
   概念が重なる。申込〜契約確定は本来 `applications`／案件側のワークフローで持ち、顧客側は
   有効/退会程度に縮退できる可能性がある。**R5 の状態機械設計時に、申込ステータスの遷移を
   案件側から導出（同期）するか独立管理のままにするかを決める**こと。一斉通知フィルタ
   （`Notification#customer_recipients`）と `Customer.active`／Devise 認証可否が8値（特に withdrawn）に依存している点に注意。
2. **`order_statuses.code` の複合形式（`10:作業進行中`）**: レガシー実値をそのまま code に
   しているため、番号とラベルが code 内で癒着している。R5 の統廃合・状態機械実装時に
   code を安定キー（例: `in_progress`）へ正規化するか、移行互換を優先して現形式を維持するかは
   **R5 のスコープ**（Q-B では決めない。ただし正規化するなら移行マッピング B-6（R7）と同時が最安）。
   なお `OrderStatus::CODE_ORDERED = "0:受注"` は `Order#assign_default_status` から参照されるため、正規化時は定数側も更新する。
3. **統廃合5値の扱い**（受注／作業進行再依頼／対応・確認依頼／作業再開依頼／強制解約(不正)）:
   `legacy-research/03` §3 の削除・統合指針は Seeder 反映前。**Rails 版 `StatusSeeder::ORDER_STATUSES` は5値のみ**で35値の投入自体が未了。
   R5 実装時に is_active=false 化 or 削除＋旧→新マッピングを行う（Q-B の範囲外、参照のみ）。
4. **「顧客ステータス」語の現場向け移行案内**: 導入研修・マニュアル（Q-20 → R8 運用教育）で
   「旧・顧客ステータス＝新・案件ステータス」の読み替え表を配る必要がある。マニュアル作成時に回収。
5. **（2026-08-19 追加）customer_statuses の code 識別子が Laravel シードと異なる**（§1-1）:
   `needs_correction`/`confirm_call_pending` 等（Rails）vs `reviewing`/`awaiting_call` 等（Laravel）。業務上の値は同じ8ラベルなので Q-B には影響しないが、
   Laravel 時代の設計文書（basic-design.md 等）や R7 マッピングで旧 code を引用している箇所があれば Rails 版 code に読み替えること。
6. **（2026-08-19 追加）ステータス遷移バリデーションは未実装**（04 R6）: `CustomerStatus`/`OrderStatus` とも「マスタに code が存在するか」のみ検証し、
   遷移ルール（withdrawn→applied 等の逆行防止）は無い。R5 状態機械（Order 側）と R6 遷移バリデーション（Customer 側）を切り分けて設計する。

---

## 6. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-26 | 初版。Q-B の実コード調査・呼称マトリクス・整理案（案A推奨）・影響範囲を作成 |
| 2026-07-26 | D-8 として案A承認（`development-plan.md` §8 Q-B ✅）: 用語3語確定・「顧客ステータス」使用禁止語化・テーブルリネームなし |
| 2026-08-19 | Rails版改訂。Laravel 固有記述（`JasminCustomer`/`JasminOrder`・`database/migrations/*.php`・`SampleDataSeeder`・Vue 画面）を Rails 版（`Customer`/`Order`・`CustomerStatus`/`OrderStatus`・`SystemManagedStatus` concern・`StatusSeeder`・ERB 画面）へ書き換え。§0-1 に実装適用状況の突合（order_statuses 側マスタ画面は適用済み／customer_statuses 側と案件画面の明示は未適用）を追加、§4-1/4-1b に修正対象ファイル・行を実ファイルで再確認して列挙。§1-4（InquiryStatus）・§5-5/5-6（code 識別子差分・遷移バリデーション未実装）を追加 |
