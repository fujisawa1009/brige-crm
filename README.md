# brige-crm

ジャスミンCRM（Laravel）のRails再構築。設計・要件は `requirements/design/` を正とする
（特に `04-rails-implementation-plan.md` がフェーズ計画、`03-rails-architecture-proposal.md` が技術構成・決定録）。

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

## 画面確認ガイド（申込フォーム）

AILINK / BRIDGE_PLUS の申込フォームを画面で確認する2つの方法。事前に「セットアップ（Docker）」で
コンテナ一式（web / db / mailpit）が起動していること。

### ① 申込フォーム本体を営業担当者として実操作する

営業担当者ログイン（代理店コード＋営業担当者コード＋メールOTP）から、実際の申込フローを
ステップ1〜8まで通しで確認する方法。

| 手順 | 操作 |
|---|---|
| 1 | http://localhost:3000/form/login を開く |
| 2 | 販売店コードと営業担当者コード（下記）を入力してログイン |
| 3 | 別タブで http://localhost:8025 （Mailpit）を開き、届いた認証コード（OTP）をフォームに入力 |
| 4 | 商材選択画面で「AILINK」（または「BridgePlus」）を選ぶ |
| 5 | ステップを順に入力して進む（必須項目のみ埋めれば次へ進める）。最後の確認画面で「申込完了」 |

**開発用ログイン情報（development の `bin/rails db:seed` 投入分）:**

- 販売店コード: `52314510`（株式会社壱（取次））
- 営業担当者コード: `SR2`（伊藤 大輔）
- OTP送信先メール: `sales-test@example.com`（実メールは飛ばず Mailpit http://localhost:8025 に届く）

※ 営業担当者は開発用サンプルデータ（`db/seeds/sample_transactions.rb`・FactoryBot生成）のため、
DBを作り直すとコードが変わることがある。現在のDBで使えるコードは以下で確認できる:

```bash
RAILS_MASTER_KEY=$(cat config/master.key) docker compose exec web bin/rails runner '
SalesRepresentative.where(is_active: true).where.not(email: nil).each do |r|
  puts "販売店コード=#{r.agency.agency_code}（#{r.agency.name}） 営業担当者コード=#{r.sales_rep_code}（#{r.name}） OTP宛先=#{r.email}"
end'
```

送信後の確認先: 管理画面（http://localhost:3000/admin/dashboard）の顧客一覧・案件一覧に反映される。
申込確認メールも Mailpit に届く。テスト送信した申込データは開発DBに残る点に注意。

### ② フォーム定義の一覧を管理画面で確認する（入力せず全項目を見たい場合はこちらが早い）

管理画面のフォームビルダーで、全ステップ・全フィールド（ラベル / 必須 / 選択肢 / 保存先カラム）を
一覧・編集できる。

| 手順 | 操作 |
|---|---|
| 1 | http://localhost:3000/admin/form_templates を開く |
| 2 | `admin@example.com` / `Password1234` でログイン（上記 [ログイン情報] と同じ） |
| 3 | 一覧から「AILINK 申込フォーム」（8ステップ112フィールド）または「BRIDGE_PLUS 申込フォーム」を開く |

※ フォームビルダーでの手動編集はシーダー（`AilinkFormTemplateSeeder` / `BridgePlusFormTemplateSeeder`）
の再実行で上書きされない（「無ければ作る」冪等投入。マスタ由来の選択肢のみ毎回同期）。

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
