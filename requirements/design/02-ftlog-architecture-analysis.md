# ftlog アーキテクチャ分析（brige-crm 参考用）

- 対象: `projects/ftlog/`（マルチテナントSaaS型のプロジェクト管理／顧客ポータル）
- 目的: brige-crm（Rails製CRM）構築にあたり、参考にすべきアーキテクチャ・特に**エンドポイントごとの権限管理**の実装を解剖する
- 作成: 2026-08-14（分析エージェントによる調査結果を秘書が整理）

---

## 0. 要点サマリ

ftlog の認可は **2層構造**:

| レイヤ | 担当 | 実装 |
|---|---|---|
| レイヤー1: エンドポイントRBAC | 「どのロールがこの操作（ルート）を実行できるか」 | 自作（gemなし）。ルート署名を権限単位にした4テーブル + 全リクエスト before_action フェイルクローズ |
| レイヤー2: レコード認可 | 「この特定レコードを操作できるか」 | Pundit |

**コントローラに個別の権限宣言を書かず、ルート署名（controller#action + HTTPメソッド）で自動ゲートする**設計が最大の移植価値。

---

## 1. 技術スタック

- **Ruby 3.4.4 / Rails 8.1.3**
- **DB: PostgreSQL**（全文検索に `pg_bigm` 拡張。db/ に専用 Dockerfile でビルド）
- **アプリサーバ: Puma + Thruster**（HTTPキャッシュ/圧縮/SSL終端）
- **フロント: Hotwire + importmap（ビルドレス）**
  - `importmap-rails` + `propshaft` + `turbo-rails` + `stimulus-rails`
  - `tailwindcss-rails`（Tailwind v4、Nodeレス。compose に tailwind watch 専用コンテナ）
  - SPA/API分離ではなく **サーバーレンダリングERB + Hotwire**。JSON用に `jbuilder` 同梱
- **認証: Devise**（招待制・公開登録ブロック）＋自作メールOTP 2FA
- **認可: Pundit（レコード単位）＋ 自作エンドポイントRBAC**
- **マルチテナント: `acts_as_tenant`**（`organization_id` 自動スコープ・`require_tenant = true` フェイルクローズ）
- **Redisレス Solidスタック**: `solid_cache` / `solid_queue`（専用workerコンテナ）/ `solid_cable`
- **レート制限: `rack-attack`**（ストア=Solid Cache）
- **ストレージ: Active Storage + S3**、`image_processing`、`rubyzip`
- **デプロイ: Kamal**
- **開発/テスト**: RSpec + FactoryBot + faker、bullet（N+1）、simplecov、brakeman、bundler-audit、rubocop-rails-omakase、annotaterb、rails-erd、letter_opener_web、capybara+cuprite
- **ページネーションgemは不在**（kaminari/pagy 無し。brige-crm では要選定）

### Docker構成
- `Dockerfile`: マルチステージ、非rootユーザ、`ENTRYPOINT bin/docker-entrypoint` → **起動時に `permissions:sync` を自動実行**（権限カタログ同期。重要）
- `docker-compose.yml`: `db`(pg_bigm独自ビルド) / `web` / `tailwind`(watch) / `worker`(Solid Queue) の4サービス

---

## 2. エンドポイントごとの権限管理（最重要）

### 2-1. データモデル（RBAC 4テーブル）

```
SystemPermission（権限カタログ・グローバル）
  controller / action / http_method / path / section("staff"|"customer") / enabled / name
  UNIQUE(controller, action, http_method, path) = route_signature

SystemRole（ロール・organizationスコープ = acts_as_tenant）
  name(不変キー) / display_name / super_admin / portal / system(組み込み) / position
  UNIQUE(organization_id, name)
  組み込み6ロール: system_admin(super_admin=true) / project_admin / developer /
                   customer_contact / viewer / customer(portal=true)

SystemRolePermission（ロール×権限 中間）
  UNIQUE(system_role_id, system_permission_id)

UserSystemRole（ユーザー×ロール 多対多）
  UNIQUE(user_id, system_role_id) + 組織一致バリデーション（越境防止）
```

設計上のポイント:
- **SystemPermission はグローバル（全テナント共通のルートカタログ）、SystemRole はテナント別**という非対称設計
- ロール種別判定は **name文字列ではなく boolean フラグ**（`super_admin?` / `portal?`）— リネームで種別を取り違えない
- 組み込みロールは削除・リネーム不可（`before_destroy` ガード + バリデーション）
- User は STI（`type`: Staff / Customer）

### 2-2. リクエスト時のチェックフロー

`app/controllers/application_controller.rb`（全コントローラの親）:

```ruby
before_action :authenticate_user!            # Devise 認証
before_action :ensure_user_is_active         # 無効化アカウント排除
before_action :set_current_attributes        # テナント確定（★認可より先が必須）
before_action :redirect_customer_to_portal
before_action :authorize_system_permission!  # レイヤー1 認可（本体）

def authorize_system_permission!
  return if skip_system_permission_authorization?   # devise系・招待系のみ除外
  return if SystemPermissionChecker.allowed?(
    user: current_user,
    controller: controller_path,
    action: action_name,
    http_method: request.request_method)
  raise Pundit::NotAuthorizedError                  # → flash + リダイレクト
end
```

- **実リクエストの `controller_path` / `action_name` / HTTPメソッドをそのままキーに判定**するため、各コントローラに権限宣言を書く必要がない（before_action 1本で全アクション自動ゲート）
- テナント解決はサブドメイン(slug) → カスタムドメイン(domain) → ログインユーザー所属組織の順でフォールバック

### 2-3. 判定ロジック: `SystemPermissionChecker`（app/services/）

```ruby
def allowed?
  return false unless user.present?
  if user.staff?
    return true if user.system_roles.exists?(super_admin: true)  # SAバイパス
    staff_allowed?
  elsif user.customer?
    customer_allowed?    # portal:true ロール保持が前提
  else
    false
  end
end

def matching_permissions
  SystemPermission.enabled.where(
    controller:, action:, http_method: [http_method, "ALL"])  # "ALL"=メソッド非依存
end
```

判定要件（**フェイルクローズ**）:
1. `super_admin` ロール保持スタッフはカタログ未登録でも全許可
2. それ以外は「①該当ルートの SystemPermission（enabled）が存在」**かつ**「②ユーザーのいずれかのロールに割当済み」の両方必須
3. staff / customer で `section` 分離

### 2-4. ルート→権限カタログの自動同期: `SystemPermissionSyncService`

- `Rails.application.routes.routes` を走査して SystemPermission を **find_or_initialize → 生成/更新**（冪等）
- 現ルートに存在しない有効権限は `enabled: false` に無効化。除外対象（active_storage/ rails/ devise/ 等）は削除
- `portal/` 始まりのコントローラは自動で `section: "customer"`
- **起動時に自動実行**（`bin/docker-entrypoint` → `permissions:sync` rakeタスク）→「新ルート追加＝カタログ未登録エラー」を構造的に防ぐ

### 2-5. ロール→権限の既定マトリクス: `OrganizationRoleSeeder`

- 組織作成時（`Organization#after_create`）と seeds の両方から呼ばれる冪等な単一入口
- ロールごとの権限方針を**コードで宣言**:
  - `SYSTEM_ADMIN_ONLY_CONTROLLERS`（role/permission管理・監査ログ・組織設定 等）
  - `SEALED_CONTROLLERS`（封印＝誰にも付与しない）
  - `SELF_SERVICE_CONTROLLERS`（dashboard/mypage/notifications 等）
  - project_admin = SA専有・封印以外の全staff権限 −（issues/comments の destroy）… のような集合演算で付与
- `grant` は**追加のみ（剥奪しない）**。マトリクス縮小の反映は rake `permissions:resync_built_in_roles`（破壊的再同期・画面カスタマイズは破棄）

### 2-6. シード／運用ルール

- `db/seeds.rb`: SyncService → 全組織に RoleSeeder → サンプルデータ
- **運用ルール（CLAUDE.mdに明文化）**: 新ルート追加時は「①カタログ登録（自動）＋②ロール付与（手動）」の両方を完了させる。片方欠けると super_admin 以外全員拒否（フェイルクローズの副作用。過去に付与漏れ再発事例あり）
- CI に **tenant_isolation ジョブ**（テナント分離違反・認可スキップの許可リスト外使用を grep で機械検出）

### 2-7. 管理UI

- `permission_management#index/update/sync`: 「権限×ロール」チェックボックスマトリクス画面。super_admin 列は「全許可」バッジで編集不可。update はトランザクションで差分作成/削除
- `role_management`: カスタムロールCRUD + reorder。組み込みロールは name 変更不可

### 2-8. ビューでの出し分け

```erb
<%# レイヤー1（RBAC）とレイヤー2（Pundit）を AND で併用 %>
<% if can_access_system_action?("comments", "destroy", http_method: "DELETE") && policy(comment).destroy? %>
```

`can_access_system_action?` は ApplicationController の helper_method（内部で SystemPermissionChecker を呼ぶ）。

---

## 3. 認証（Devise + 自作OTP）

- Devise: `:database_authenticatable, :registerable, :recoverable, :validatable, :lockable, :timeoutable`
- 招待制（公開登録ブロック・自作 invitation_token）
- **メールOTP 2FA（自作）**: `otp_code_digest`（SHA256ハッシュのみ保存）/ 10分期限 / 試行5回上限 / `secure_compare`。組織設定 `otp_required` + IP許可リスト外のみ要求
- パスワード認証成功後 `warden.authenticate!(store: false)` で**セッションに載せず**OTP要否判定
- rack-attack でOTP照合・再送・パスワードリセットをレート制限
- ソフトデリート（`deleted_at`）+ `active_for_authentication?` 拡張
- Devise通知メールは `deliver_later`（SMTP障害でユーザー操作を500にしない）

---

## 4. アプリ構造の規約

- レイヤ: `controllers/`（portal/ platform_admin/ projects/ users/ のネームスペース）、`models/`、`policies/`、`services/`（ビジネスロジック集約。forms/ decorators/ は無し）、`jobs/`、`mailers/`
- **`Current`（CurrentAttributes）**: user / organization / ip_address / request_id。`organization=` セッターで `ActsAsTenant.current_tenant` 自動同期
- concerns: `Auditable` / `AuthAuditable` / `UserAdminAuditable`（監査）、`CustomSignInRedirect`、`WikiFeatureGuard`（機能フラグ）
- モデル先頭に annotaterb スキーマ注釈必須
- `.unscoped` / 生SQL 原則禁止。organization_id を持つ新モデルは必ず acts_as_tenant

---

## 5. DB設計（概要）

- テナント境界 = `organizations`（slug/domain でテナント解決、default_system_role_id、otp_required 等）
- RBAC 4テーブル（前述）
- User STI（Staff/Customer）、UNIQUE(organization_id, email)、ソフトデリート
- 業務系: projects / project_members / issues / comments / issue_types・categories・statuses / custom_field_definitions・values / project_files・folders / wiki_pages / notifications / audit_logs / ip_allowlist_entries
  - ⚠️2026-08-15洗い直しで訂正: `customers`という独立テーブルは存在しない（Customerは`users`テーブルのUser STIサブクラス。`app/models/customer.rb`参照）。`login_histories`も独立テーブルではなく、`LoginHistoriesController`が`AuditLog`を`AuthAuditable::AUTH_ACTIONS`で絞り込んで表示する画面（専用テーブルなし）
- マスタは「システムプリセット → 組織マスタ → プロジェクト個別」の3層継承
- ERD: `erd.mmd` / `erd.pdf`（rails-erd 生成）

---

## 6. テスト

- RSpec + FactoryBot。**request spec 中心 + policy spec + service spec**
- **認可テストハーネス**（`spec/support/system_permission_authorization.rb`・移植価値大）:
  - 既定を**実認可（フェイルクローズ）**にし、`:skip_system_authorization` タグや許可リストファイルで明示的にのみスタブ
  - （旧実装は既定スタブ＝フェイルオープンで回帰を検出できなかった教訓から反転）
  - `:seed_permission_catalog` タグで SyncService 実行 → organization 作成時に本番同等マトリクス自動付与
  - `grant_system_permissions!(role, "wiki_pages", actions: %w[destroy])` ヘルパー

---

## 7. brige-crm への流用価値まとめ

| パターン | 移植価値 | 備考 |
|---|---|---|
| エンドポイントRBAC一式（4モデル + Checker + SyncService + RoleSeeder + before_actionゲート + マトリクスUI） | ★★★ 中核 | コントローラ個別宣言不要・自動ゲート |
| 2層認可（RBAC=操作可否 / Pundit=レコード可否） | ★★★ | 責務分離が明快 |
| 認可テストハーネス（既定=実認可） | ★★★ | 回帰検出の要 |
| 監査ログ concern（Auditable 系） | ★★☆ | CRMでも顧客データ操作の監査に有効 |
| Solidスタック（Redisレス） | ★★☆ | 運用簡素化 |
| importmap + Tailwind + Hotwire（ビルドレス） | ★★☆ | フロント方針次第（Laravel側はVueのため要判断） |
| Devise + メールOTP + rack-attack | ★★☆ | CRMの機微情報保護に |
| CI の認可スキップ検出 grep ガード | ★★☆ | |
| マルチテナント（acts_as_tenant） | ★☆☆ | **brige-crm が単一テナントなら不要**。SystemRole のテナントスコープ・RoleSeeder を単純化できる |

### 移植時の注意
- SystemPermission=グローバル / SystemRole=テナント別の**非対称**。単一テナントなら SystemRole のスコープを外し、`OrganizationRoleSeeder` を `RoleSeeder`（起動時 or seed 時1回）に単純化
- フェイルクローズの副作用「新ルート追加→付与漏れ→全員拒否」への対策（起動時sync + 既定マトリクスのコード宣言 + CIガード）をセットで移植すること

### 主要参照ファイル（ftlog内パス）
- 認可コア: `app/controllers/application_controller.rb` / `app/services/system_permission_checker.rb` / `app/services/system_permission_sync_service.rb` / `app/services/organization_role_seeder.rb` / `lib/tasks/permissions.rake`
- モデル: `app/models/system_permission.rb` / `system_role.rb` / `system_role_permission.rb` / `user_system_role.rb` / `user.rb` / `current.rb`
- 管理UI: `app/controllers/permission_management_controller.rb` / `role_management_controller.rb` / `app/views/permission_management/index.html.erb`
- テスト: `spec/requests/system_permission_authorization_spec.rb` / `spec/support/system_permission_authorization.rb`
