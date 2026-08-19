# brige-crm

ジャスミンCRM（Laravel）のRails再構築。設計・要件は `requirements/design/` を正とする
（特に `04-implementation-plan.md` がフェーズ計画、`03-rails-architecture-proposal.md` が技術構成・決定録）。

## セットアップ（Docker）

`config/master.key` は非コミット（.gitignore対象）。別途配布された鍵をこのパスに置くか、
`RAILS_MASTER_KEY` 環境変数で直接渡すこと。

手順は以下の通りです。既存の config/credentials.yml.enc は鍵を持たないと復号できないため、いったん退避してから新規生成します。

[初回手順]
1. 既存 config/credentials.yml.enc をバックアップ（念のため）してから削除
2. docker compose build web（アセットprecompileはダミーのSECRET_KEY_BASEを使うため鍵不要）
3. docker compose run --rm -e EDITOR=true web bin/rails credentials:edit
→ コンテナ内で config/master.key と新しい config/credentials.yml.enc が生成され、bind mount経由でホスト（このリポジトリ）にも反映されます
4. 生成された config/master.key の存在・パーミッションを確認

```bash
RAILS_MASTER_KEY=$(cat config/master.key) docker compose build
RAILS_MASTER_KEY=$(cat config/master.key) docker compose up -d db
RAILS_MASTER_KEY=$(cat config/master.key) docker compose run --rm web bin/rails db:prepare
RAILS_MASTER_KEY=$(cat config/master.key) docker compose up
```

- web: http://localhost:3000
- mailpit（開発用SMTPキャッチャー。OTPメール等の確認用）: http://localhost:8025

[ログイン情報]
- メールアドレス: admin@example.com
- パスワード: Password1234
- ロール: admin（super_admin相当）

## セットアップ（ローカルRuby + Docker db のみ）

db だけDockerで立て、Railsはホストのrbenv Rubyで動かす場合:

```bash
docker compose up -d db
export POSTGRES_HOST=localhost POSTGRES_PORT=5433 POSTGRES_USER=brige_crm POSTGRES_PASSWORD=brige_crm_password
bin/rails db:prepare
bin/rails server
```

## テスト

```bash
export POSTGRES_HOST=localhost POSTGRES_PORT=5433 POSTGRES_USER=brige_crm POSTGRES_PASSWORD=brige_crm_password RAILS_ENV=test
bin/rails db:test:prepare
bundle exec rspec
bin/rubocop
bin/brakeman
bin/bundler-audit
```

## 認可（エンドポイントRBAC + Pundit）

`requirements/design/02-ftlog-architecture-analysis.md` と `review/review-02-ftlog-analysis.md` を必読。

- レイヤー1（操作可否）: `SystemPermission`/`SystemRole`/`SystemRolePermission`/`UserSystemRole` +
  `SystemPermissionChecker` + `SystemPermissionSyncService`（`rails permissions:sync`。サーバー起動時に
  `bin/docker-entrypoint` が自動実行）+ `RoleSeeder`（`rails permissions:seed_roles`）
- レイヤー2（レコード可否・参照スコープ）: Pundit。`app/policies/application_policy.rb` の
  `Scope#resolve` は必ずオーバーライドすること（既定はNoMethodErrorでフェイルクローズ）
- section 3区分（admin/form/mypage）。ロール割当の編集対象は admin section のみ。
  form section は `authorize_system_permission!` を完全スキップする（独自FormAuthで保護。R3で実装）
- 新しいコントローラ/アクションを追加したら、`rails permissions:sync` でカタログに登録した上で
  `RoleSeeder`（既定マトリクス）かロール管理UI（`/admin/permission_management`）で権限を付与すること。
  付与を忘れると super_admin(admin) 以外は全員拒否される（フェイルクローズの副作用）

## テスト基盤の認可ハーネス

`spec/support/system_permission_authorization.rb` が request spec の既定を実認可（フェイルクローズ）にする。
新規specは基本そのまま書けばよい。一時的にバイパスしたい場合は `:skip_system_authorization` タグを使うこと
（`spec/support/fail_open_request_specs.txt` はレガシー据え置き用でR0時点では空。新規追加は原則禁止。
CIの `authorization_guard` ジョブが追加をブロックする）。

## 開発用シードユーザー

`bin/rails db:seed`（development環境のみ）で `admin@example.com` / `Password1234`（adminロール）を作成する。
