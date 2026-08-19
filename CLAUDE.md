# CLAUDE.md

このファイルはClaude Code（および他のAIコーディングエージェント）がこのリポジトリで作業する際に守るべき規約を記載する。

## git運用（AIによるcommit/push、2026-08-20 CEO決定）

- **通常の対話セッション**（人間がCLIで直接開発）では `git commit` / `git push` はユーザーが手動で行い、AIは提案のみで実行しない。
- **ただし秘書（AI-CEO Framework）経由の自律開発フローで明示的に委任された場合に限り**、AIが直接 `git commit` / `git push` してよい。
  - 対象は**現在の作業ブランチのみ**（例: `feat/rails-rebuild-r0-r4`）。`main`/`master` へ直接pushしない。
  - **push前提はテストgreen**：`docker compose run --rm web bin/rails db:test:prepare && bundle exec rspec`（および必要に応じ `bin/rubocop` / `bin/brakeman`）が通ることを確認してからcommit/pushする。
  - コミットメッセージに AI 帰属トレーラー（`Co-Authored-By: Claude ...` 等）は付けない（親リポ・CEO指示 2026-07-18と同じ方針）。author/committer は既に人間（git config）のため不要。
  - 親リポの `scripts/ai-git.sh` は使わない（あれは親リポ専用ゲート）。子リポでは通常の `git` コマンドを直接使う。
- 破壊的操作（`git reset --hard` / `git push --force` / `git checkout --` 等）はAIが自律実行フロー中でも使わない。詰まった場合は作業を止めてCEOに報告する。

## テスト・検証

- Docker Compose環境（`docker-compose.yml`）で `web`/`db` を起動し、`bundle exec rspec` で検証する。
- 自律実行フロー中は「実装→テスト実行→green確認→commit」のサイクルを1タスクごとに回す。redのままcommitしない。
- 認可・監査ログ・テナントスコープに関わる変更は、既存の `spec/requests/admin/*_spec.rb` のパターンに倣ったrequest specを追加すること（R0〜R5で確立された規約）。

## ドメイン・アーキテクチャの詳細

実装計画・設計判断・用語定義は `requirements/design/04-rails-implementation-plan.md` を正とする。個別トピックは同ディレクトリの各設計文書（`basic-design.md` 等）を参照。
