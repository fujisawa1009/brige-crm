# 本番リリース準備 チェックリスト（リリース可否の判断軸）

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/release-readiness.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。フェーズ対応: **R8（品質保証・リリース準備）**。R5（契約フロー・決済）／R7（データ移行）に属する項目は該当フェーズを併記。突合対象: `Gemfile` / `Dockerfile` / `docker-compose.yml` / `config/deploy.yml` / `config/environments/production.rb` / `config/{queue,cache,cable,recurring,storage}.yml` / `.github/workflows/ci.yml` / `config/initializers/rack_attack.rb` / `app/**` / `spec/**`。
>
> **基盤スタックの正は `03-rails-architecture-proposal.md` §2（技術スタック）および §8 決定録**。本書のインフラ・キュー・監視系の記述はそれに従属する。旧Laravel側の決定（RDS MySQL 8.4 LTS・Redis/Horizon・Reverb・SES/S3 前提の AWS 構成案 = 削除済み `basic-cost.md`）は Laravel 側限定の旧決定であり、本書では「旧決定」と明記のうえ Rails 版へ置換した。

> 作成日: 2026-07-24（Laravel版）
> ステータス: 2026-08-19 Rails版へ全面改訂（R0〜R4 実装済み範囲を突合）
> 対象フェーズ: `04-implementation-plan.md` **R8**（および R0〜R7 に横断する非機能要件）。旧Laravel P5 相当
> 目的: **機能実装（R0〜R6）とは別軸で、本番リリースに必要な作業を漏れなく洗い出す**

---

## 0. 本書の位置づけ

R0〜R6 は**機能**の計画。本書は「機能が全部できても、これが無いと本番に出せない」
**非機能・運用・法務・体制**を集約する。リリース判定は本書の項目で行う。

### 状態ラベルの凡例（各項目に付与）

| ラベル | 意味 |
|---|---|
| ✅ 実装済み | brige-crm の現行コード／設定で満たしている（突合日 2026-08-19） |
| 🔶 部分実装 | 基盤はあるが本番要件を満たすには追加作業が要る |
| ⬜ 未着手（R8） | R8 で実施する作業（他フェーズに属する場合は Rx を併記） |
| ❓ 要決定 | CEO／業務側／情シスの決定・確認待ち。`development-plan.md` §8 の Q 番号を併記 |

### 全体像（10領域）

| 領域 | 現状（2026-08-19） | 深刻度 |
|---|---|---|
| A. インフラ・デプロイ基盤 | 🔶 本番用 Dockerfile（Puma+Thruster）・Kamal 雛形（`config/deploy.yml`、宛先未定）・Solid Queue/Cache/Cable の本番設定は生成済み。本番先・ドメイン・TLS・SMTP・ストレージは未定 | 🔴 |
| B. データ移行（現行→新） | 🔄 設計済み（`legacy-research/08`〜`10`・`name-matching-process.md`）。実装は **R7（別プロジェクト切り出し・決定F）** | 🔴 |
| C. セキュリティ | 🔶 RBAC/Pundit/監査/OTP/IP許可リスト/rack-attack/PII暗号化/CI（brakeman・bundler-audit・認可ガード）は実装済み。外部診断・本番ハードニング（force_ssl 等）は未 | 🔴 |
| D. 決済・契約の非機能要件 | ⬜ **R5 未着手**。要件は本書に保持 | 🔴 |
| E. 監視・ログ・バックアップ | 🔶 STDOUT タグ付きログ・`/up`・AuditLog・Solid Queue recurring は実装済み。外部監視・バックアップは未 | 🔴 |
| F. テスト・品質保証 | 🔶 RSpec 38 ファイル（request 19・model 12・job 4・service 3）。認可・参照制御・OTP・申込トランザクションはカバー。契約/決済（R5）・E2E・UAT は未 | 🟠 |
| G. 法務・コンプライアンス | ⬜ 未着手（R8。**リードタイム長・今から並行**） | 🔴 |
| H. 運用・サポート体制 | ⬜ 未着手（R8） | 🟠 |
| I. リリースプロセス | ⬜ 未定義（R8。カットオーバーは R7 と連動） | 🟠 |
| J. 性能・可用性 | ⬜ 未検証（R8） | 🟡 |

---

## A. インフラ・デプロイ基盤 🔴

**Rails版の前提（03§2）**: PostgreSQL 16（+pg_bigm）／Solid Queue・Solid Cache・Solid Cable（**Redisレス**）／Puma + Thruster（`Dockerfile` 既定 CMD `./bin/thrust ./bin/rails server`）／デプロイは **Kamal 雛形あり・採否未定**（03§2「デプロイ: 未定（社内インフラ次第）」）。

| # | 項目 | 状態 | 現状・Rails版での内容 |
|---|---|---|---|
| A-1 | 本番 DB | ❓ 要決定（ホスティング先）／✅ 種別は決定済み | **旧決定（Laravel側限定）: 「RDS は MySQL 8.4 LTS で構築」→ 廃止。03 決定A（PostgreSQL）が正。** 本番は **PostgreSQL 16 系**（pg_bigm 拡張が使えること。開発は `db/Dockerfile` で同梱、RDS/Aurora では標準サポート拡張）。`config/database.yml` production は primary / cache / queue / cable の **4 DB 構成**（Solid 系を別DBに分離）。ホスティング先（RDS / 自前 PostgreSQL コンテナ = Kamal accessory 等）は未定 → **Q-40**。 |
| A-2 | ステージング環境 | ⬜ 未着手（R8） | 無し。本番と ホスト/ドメイン/DB(4本)/ストレージ/SMTP送信元/`RAILS_MASTER_KEY`/credentials/Solid Queue worker/recurring/ログ/バックアップ保持期間 を分離する。Kamal を採る場合は `config/deploy.staging.yml`（destination）で分ける。使用データ種別は **Q-43** |
| A-3 | CI/CD デプロイパイプライン | 🔶 部分実装 | CI は `.github/workflows/ci.yml` で **scan_ruby（brakeman・bundler-audit）／scan_js（importmap audit）／lint（rubocop）／test（PostgreSQL 16+pg_bigm コンテナ・`db:schema:load`・tailwind build・rspec）／authorization_guard（認可スキップ検出・フェイルオープン許可リスト shrink 監視）** の 5 ジョブが稼働（`bin/ci` = `config/ci.rb` でローカル一括実行も可）。**デプロイ自動化は無し**。`kamal deploy` の手順化、`db:migrate`（Kamal は `docker-entrypoint` の `db:prepare` + `permissions:sync` で起動時に実行）、メンテナンス表示、`Rails.cache.clear`、worker 再起動、rollback（`kamal rollback`）手順は未定義（R8） |
| A-4 | シークレット管理 | 🔶 部分実装 | Rails credentials（`config/credentials.yml.enc` + `RAILS_MASTER_KEY`）が既定。DB パスワードは ENV `BRIGE_CRM_DATABASE_PASSWORD`、Kamal は `.kamal/secrets` 経由で `RAILS_MASTER_KEY` を注入。本番で追加になる秘匿値: SMTP 認証、ActiveRecord::Encryption 鍵（credentials）、ネットムーブ HMAC キー（R5）、ストレージ資格情報、レジストリ認証。**Laravel 側の APP_KEY/Reverb キー等は不要**。保管先（credentials 一本 / SSM・Secrets Manager 併用）は R8 で決定 |
| A-5 | リバースプロキシ配下の IP 取得（旧 `TrustProxies`） | ⬜ 未着手（R8） | Rails では `ActionDispatch::RemoteIp`（`config.action_dispatch.trusted_proxies`）と `config.assume_ssl` で対応。**IP許可リスト（`IpAllowlistEntry.allows?(request.remote_ip)`）と AuditLog の IP 記録が `remote_ip` に依存**するため、ALB/Kamal proxy/Cloudflare 配下で `X-Forwarded-For` を正しく信頼する設定を本番構成確定時に必ず入れる（誤ると全員同一IPに見え IP許可リストが無意味 = 旧 ftlog-port §2-5 と同じ論点）。`force_ssl` / `assume_ssl` は現在 `production.rb` でコメントアウトのまま（04 R3 見送り事項） |
| A-6 | ジョブ／スケジューラの本番常駐 | 🔶 部分実装 | Solid Queue（`config/queue.yml`: dispatcher 1 / worker `queues: "*"` threads 3 / `JOB_CONCURRENCY`）。recurring は `config/recurring.yml`（finished jobs の定期削除・`SystemNotification.prune_expired!` 毎日2時）で **cron 不要**。実行形態は未決: `SOLID_QUEUE_IN_PUMA=true`（`deploy.yml` 既定・単一サーバ向け）か 専用 job ホスト（`bin/jobs`）か。**決済専用キュー＋自動リトライ無効化（R5・payment-integration §4-2）を追加する際は `queue.yml` の worker 定義も分ける**。失敗ジョブ運用（再実行・破棄）の手順とダッシュボード（`mission_control-jobs` 導入要否）は R8 で決定 |
| A-7 | WebSocket（旧 Reverb） | ✅ 実装済み（構成）／⬜ 本番検証（R8） | Solid Cable（`config/cable.yml` production: `solid_cable` / polling 0.1s / retention 1日）。`/cable` を Puma 同一プロセスで配信するため専用ポート不要。ALB/プロキシの WebSocket パススルー・アイドルタイムアウトを本番構成で確認 |
| A-8 | ファイルストレージ（旧 S3 切替） | 🔶 部分実装 | Active Storage `:local`（`config/storage.yml` の `local` Disk。Kamal では volume `brige_crm_storage`）。現在の添付: 問い合わせ添付・営業資料・ユーザCSV取込。R5 で契約書PDF・署名画像が加わる。本番でオブジェクトストレージ（S3 互換）へ切り替えるか Disk+バックアップで運用するかは **Q-40 と併せて決定**。切替時は署名付きURL・公開範囲・既存 local データの移行を定義 |
| A-9 | HTTPS/証明書・ドメイン | ❓ 要決定（Q-42） | 未設定。Kamal 採用時は `proxy: ssl: true`（Let's Encrypt 自動）＋ `config.force_ssl` / `assume_ssl` を有効化。ALB+ACM 等の場合は終端側で TLS。ドメイン取得/移管・DNS 管理者も未定 |
| A-10 | DB リードレプリカ／接続数 | ⬜ 未着手（R8） | 未検証。`RAILS_MAX_THREADS`（既定 5）× Puma ワーカー × worker プロセス で接続数を見積る（4 DB 構成のため接続数は Laravel 単一 DB 時より増える点に注意） |
| A-11 | 構築手順書（旧 `aws-deployment-runbook.md`） | ⬜ 未着手（R8） | 未作成。**`basic-cost.md`（MySQL/ElastiCache/Horizon 前提）は削除済み**（旧Laravel側に残存）。PostgreSQL／Redisレス／Kamal or 代替 の構成で費用再試算と手順書を作る（review-05 §5） |
| A-12 | メール送信設定（旧 SES） | 🔶 部分実装 | 開発は mailpit（`SMTP_ADDRESS`/`SMTP_PORT`）。`production.rb` の `action_mailer.smtp_settings` はコメントアウト、`default_url_options.host` は `example.com` のまま → **本番送信元・SMTP プロバイダ（SES 継続か否か）・ドメイン認証（SPF/DKIM/DMARC）・`default_url_options`・`raise_delivery_errors` を R8 で設定**。OTP・Devise 通知・問い合わせ・一斉通知・スタッフ通知の 5 系統がメール依存 |
| A-13 | 本番構成方式 | ❓ 要決定（Q-40） | 未決定。候補: (a) 単一 VM + Kamal（web+worker 同居・PostgreSQL accessory）／(b) VM + マネージド PostgreSQL／(c) コンテナ基盤（ECS 等）。03§2 は「社内インフラ次第・本番要件確定後」 |
| A-14 | Ruby バージョン | ⚠️ 要確認 | 03§2 は「Ruby 3.4」だが実態は **`.ruby-version` = 3.3.4**（`Dockerfile` ARG も 3.3.4）。リリース前に 3.4 系へ上げるか 3.3 系で固定するかを決め、03§2 と揃える（`csv` gem を明示済みのため 3.4 移行時の障害は小） |

> Laravel 版の注記「CI の対象ブランチ（`main` / `0*_jasmin_base`）」は不要。現行 CI は `pull_request` と `main` への push で起動。

---

## B. データ移行（現行 → 新システム）🔴 — **R7（別プロジェクト切り出し・決定F）**

**M-2 は解消**（現行DB全件が資料内）。構造把握と整形設計は済み。実装は R7。R2 スキーマとの整合は確認済み（04 R7・review-05 §6）。

| # | 項目 | 状態 |
|---|---|---|
| B-1 | 現行スキーマ・件数・品質の把握 | ✅ `legacy-research/08`（掲示板42万件等） |
| B-2 | 移行対象範囲（全件/稼働中/アーカイブ） | ✅ Q-C 決定済み（D-11）：新規は問い合わせ統合（R4 で Inquiry 拡張済み）、過去掲示板42万件は参照専用アーカイブ（R7） |
| B-3 | 新旧スキーマのマッピング定義 | 🔄 `legacy-research/10`（DM-2 列対応表）＋ `09`（整形ルール）。**Rails 版スキーマ（`db/schema.rb`・`jasmin_` 除去後の `customers`/`orders`/`stores`・UUID 主キー）への読み替え**は R7 着手時に実施。`customers.netmove_member_id` の取り込み枠は 04 R5/R7 |
| B-3a | **CSV破損の是正**（営業担当ヘッダ13/16列・店舗Plus 1行47列）。可能なら現行DBから再エクスポート | 🔴 未着手（`09` §1）。再エクスポート依頼はリクリック宛に送信承認済み（2026-07-26） |
| B-4 | 移行スクリプト（ETL）の開発 | ⬜ 未着手（R7）。**Artisan → rake タスク／`rails runner`** で実装（`lib/tasks/`）。方式は `09` §6 |
| B-5 | 契約条件バージョンへの過去受注の割り当て | 設計課題（basic-design §3）。Rails 版では `contract_condition_id` が **orders 側**にある（T-3 是正済み）ため割当先は受注 |
| B-6 | ステータスの新旧マッピング（統廃合適用） | 用語方針決定済み（Q-B/D-8）。旧→新マッピング実装/検証は R7。**Q-B の表示統一が `customer_statuses` 側で未完**（04 R2 追加タスク）のため R7 前に解消 |
| B-7 | 移行リハーサル（ドライラン・冪等再実行） | ⬜ 未着手（R7/R8）。本番相当データで最低2回、ETL+load 所要時間を実測 |
| B-8 | 移行データの検証（`09` §7 の V-1〜7） | ⬜ 未着手（R7） |
| B-9 | カットオーバー計画（Bridge/BP断面・停止時間） | ⬜ 未着手（R8）。旧環境停止→リクリック最終退避→整形→新環境投入の当日直列作業（`development-plan.md` §2 N-1） |
| B-10 | リクリック当日作業合意 | ❓ 未依頼（W-5 / N-1-a）。停止時刻、退避完了時刻、受渡方法、時間外対応、費用、切り戻し依頼ルート |
| B-11 | 移行ファイル一時保管ルール | ⬜ 未定義。暗号化、アクセス制限、削除期限、受渡方法を PII ルール（`pii-handling-rules.md` / Q-A）と整合 |
| B-12 | 名寄せ表作成プロセス | ⬜ 未着手（R7）。`name-matching-process.md`（機械候補→人手レビュー→版管理→リハーサル反映・精度目標97%） |

---

## C. セキュリティ 🔴

| # | 項目 | 状態 |
|---|---|---|
| C-1 | セキュリティレビュー / 脆弱性診断（外部） | ⬜ 未実施（R8）。内部レビューは R0〜R4 見直しで実施済み（OTP バイパス修正 commit `2022d67`、権限昇格バグ `1e7a0ad`、target_column ホワイトリスト `7cb7dc4` 等） |
| C-2 | 依存パッケージ脆弱性スキャンの CI 組込み | ✅ 実装済み: `bundler-audit`（`config/bundler-audit.yml`）・`brakeman`・`importmap audit` が CI で毎 PR 実行 |
| C-3 | **顧客SNS認証情報の暗号化**（現行は平文） | 🔶 部分実装／❓ Q-D: `OrderWorkDetail` の 8 カラム（system/google/instagram 等の ID・パスワード）は `ActiveRecord::Encryption` で暗号化済み（R2）。Customer 本体の PII（分類A）を暗号化しない方針は**正式決定として未記録**（04 R2 見送り事項）→ 運用開始前に文書化 |
| C-4 | 決済まわりの PCI DSS（非保持・非通過） | ⬜ 未確認（R5・payment §4-1）。ネットムーブ リダイレクト型で非保持を維持する設計は継続 |
| C-5 | 個人情報の取り扱い（保存・アクセス制限・削除） | ❓ Q-A: `pii-handling-rules.md` ドラフトあり・確定保留（D-3）。**PII取扱ルール確定前に本番相当データを本番/ステージングへ置かない**（Q-43 と連動） |
| C-6 | レート制限・ブルートフォース対策 | 🔶 部分実装: rack-attack（`config/initializers/rack_attack.rb`・Solid Cache ストア）で `/users/password`（3回/15分/メール）・`/users/otp`（10回/15分/IP）・`/users/otp/resend`（3回/15分/IP）を制限。OTP コード単位の 5 回上限は `OtpAuthenticatable`（User/Customer/SalesRepresentative 共通）。Devise `lockable`。**未対応: `/form/otp` `/form/login` `/mypage/otp` `/mypage/login` への IP スロットル、ログイン試行そのもの（`/users/sign_in`）の IP スロットル** → R8（または R5 前の小改修）で 3 系統を揃える |
| C-7 | IP許可リスト＋2FA | ✅ 実装済み（旧 P4-17 → R0/R3/R4）: `IpAllowlistEntry`（空リスト=全員 OTP 必須のフェイルセーフ）＋メールOTP を管理画面/受注入力/マイページの全 3 系統に適用（Q-23 全画面必須）。管理UI `admin/ip_allowlist_entries` |
| C-8 | CSRF/XSS/SQLi 点検 | 🔶 Rails 標準（CSRF トークン・ERB 自動エスケープ・プレースホルダ）で大半。`raw`/`html_safe`・文字列 SQL（`ILIKE :q` 等は束縛済み）を R8 で grep 点検。CSP は `config/initializers/content_security_policy.rb` が雛形のまま → 有効化を検討 |
| C-9 | ファイルアップロード検証 | 🔶 Active Storage の添付（問い合わせ・営業資料・ユーザCSV）。拡張子/MIME/サイズ検証・ウイルススキャン要否は未整理。R5 で署名画像・契約書PDF が加わる前に方針を決める |
| C-10 | 権限昇格の監査 | ✅ 実装済み: `UserSystemRole` 変更・権限マトリクス変更・権限拒否イベントは `AuditLog`（`Auditable`/`AuthAuditable`）に記録（R0 修正 `3bb033f`）。Agency/AgencyGroup 削除時の権限昇格は `restrict` FK で防止（`1e7a0ad`） |
| C-11 | バックアップデータの暗号化・アクセス管理 | ⬜ 未着手（R8・E-4 と連動）。DB ダンプ／ストレージ／移行ファイル／ログの暗号化と権限 |
| C-12 | 本番ホストのアクセス制御・監査 | ⬜ 未着手（R8）。構成方式（Q-40）確定後に、SSH/IAM 最小権限・MFA・DB 非公開・ストレージ非公開・監査証跡を定義 |
| C-13 | セッション/Cookie ハードニング（Rails版で追加） | ⬜ 未着手: `force_ssl`（secure cookie/HSTS）が未有効、セッション絶対有効期限（`expire_after`）未設定、営業担当者ログイン時の `reset_session`（session fixation）未実施、`config.hosts`（Host ヘッダ検証）未設定（04 R3 見送り事項）。**本番前に必須** |
| C-14 | ログの機密情報マスク | ✅ 実装済み: `filter_parameter_logging.rb` を `*_pass` 系カラムまで拡張（R2 修正 `50bd98d`）。R5 でカード関連パラメータ名を追加すること |

---

## D. 決済・契約の非機能要件 🔴 — **R5 未着手**（要件は保持）

| # | 項目 | 状態 |
|---|---|---|
| D-1 | ネットムーブ開通処理・HMACキー取得・本番接続審査/契約・商用カード検証計画 | ⬜ 未着手（R8・旧 P5-14。**長リード外部依存・今から並行**）。検証専用環境が無い可能性あり。ステージング検証方式は **Q-39** |
| D-2 | 決済の突合（reconciliation）運用 | 設計のみ（payment §4-3）。実装は R5。決済結果の確定手段は **Q-38** |
| D-3 | 返金・キャンセルの業務フロー | ❓ 未確定（**Q-25**・R5 着手前ブロッカー） |
| D-4 | 契約書・申込確認書・重要事項説明の法的有効性 | ⬜ 未確認（R5/R8）。電子文書、同意証跡、版管理、タイムスタンプ、改ざん防止。未決事項は **Q-35** |
| D-5 | 特定商取引法に基づく表記 | ⬜ 未整備（R8・G-5） |
| D-6 | 課金・請求の締め処理 | ✅ 方針決定（Q-24/D-P8）: 月次売上処理は TBSS 運用継続。新システムは**請求用受注データ CSV エクスポートのみ**必須 → 実装先（R5 決済の一部 or R6 P4-12 プロファイル汎用化）を R5 着手時に確定（04 R5 追記） |
| D-7 | 違約金計算ロジック（パラメータ化） | ⬜ 未実装（`legacy-research/07` §3）。R5/R6 |
| D-8 | 決済ジョブの隔離（Rails版で追加） | ⬜ 未着手（R5）: 決済専用キュー＋自動リトライ無効化（payment §4-2）。Solid Queue の `queue.yml` worker 定義分離と `retry_on` 不使用を設計に含める |
| D-9 | ネットムーブ会員ID・カード引継ぎ | 🔶 カラム（`customers.netmove_member_id` / `netmove_registered_at`）は R2 実装済み。採番連続性・`member-modify` 導線・ETL 取込枠は R5/R7（`netmove-card-migration.md`） |

---

## E. 監視・ログ・バックアップ 🔴

| # | 項目 | 状態 |
|---|---|---|
| E-1 | アプリ監視・エラー通知（Sentry 等） | ⬜ 未設定（R8）。gem 未導入。`config.log_tags = [:request_id]` で追跡は可能 |
| E-2 | インフラ監視 | ⬜ 未設定（R8）。構成方式（Q-40）確定後に対象（ホスト/PostgreSQL/ストレージ/SMTP/Solid Queue worker）を決める |
| E-3 | ログ集約・保管 | 🔶 部分実装: 本番は **STDOUT タグ付きログ**（`production.rb`）＋ `RAILS_LOG_LEVEL`。コンテナ運用ならログドライバで集約可。対象: Rails アプリ／Puma・Thruster／Solid Queue worker／recurring／デプロイ／決済連携ログ（R5）。保管先・期間・検索方法は R8 |
| E-4 | **DB バックアップ＋リストア手順**（リストア試験まで） | ❓ 未設定（**Q-41**・R8）。PostgreSQL 4 DB（primary/cache/queue/cable）のうち **primary は必須、cache/cable は再生成可、queue は要検討**。保持期間・RTO/RPO・ストレージ復旧方針 |
| E-5 | 障害通知・オンコール体制 | ⬜ 未定義（R8） |
| E-6 | ヘルスチェック | ✅ `/up`（`rails/health#show`）有効・`silence_healthcheck_path` 設定済み。監視への接続は未（R8） |
| E-7 | キュー滞留・失敗ジョブの監視 | 🔶 部分実装: Solid Queue はテーブルで状態保持（`solid_queue_failed_executions` 等）。**ダッシュボード UI は未導入**（旧 Horizon UI 相当 = `mission_control-jobs` の導入要否を R8 で決定）。滞留アラート・再実行手順は未 |
| E-8 | 監査ログ・決済ログの保全期間 | ✅ 監査ログは 5 年（Q-22/D-6）。`AuditLog` に prune 処理は無い（保持方針どおり）。決済ログ（R5）も同方針に合わせるか確認 |
| E-9 | インフラコスト監視 | ⬜ 未設定（R8）。構成方式確定後 |
| E-10 | 監査ログの運用画面（Rails版で追加） | 🔶 ログイン履歴は `admin/login_histories`（AuditLog の絞り込みビュー）で実装済み。**監査ログ全件の検索/CSV 画面は未**（旧 P4-16「検索・CSV」）→ R6 |

---

## F. テスト・品質保証 🟠

**現状**（2026-08-19）: RSpec 38 ファイル = request 19（admin 13 / form 3 / mypage 1 / users 2）・model 12・job 4・service 3。FactoryBot。認可テストハーネス（既定=実認可・`spec/support/fail_open_request_specs.txt` は shrink のみ CI 監視）。参照制御（代理店スコープ）・OTP・申込トランザクション・採番並行性・CSV スコープはカバー済み。旧 T-1（CRUD 偏重）は R0〜R4 範囲では解消。

| # | 領域 | 状態 |
|---|---|---|
| F-1 | 契約フロー（申込→不備→確認コール→契約確定） | ⬜ R5 と同時（状態機械 spec 必須・04 R5） |
| F-2 | 決済（正常・失敗・タイムアウト・二重送信・戻り改ざん） | ⬜ R5。**手動再現不可＝自動必須**（payment §6） |
| F-3 | 参照制御（代理店スコープ）の網羅 | ✅ 実装済み（R1/R2 request spec: 一覧・詳細・更新・CSV）。**未カバー: 通知宛先検索・問い合わせ宛先解決・マイページ**の代理店スコープ → R8（または R6）で横断テスト追加 |
| F-4 | E2E（ブラウザ通し） | ⬜ 未導入（R8）。system spec（Capybara + cuprite/selenium）か Playwright を選定。マニュアル生成（H-1）と基盤共通化を検討 |
| F-5 | ステータス遷移の網羅 | ⬜ R5（契約状態機械）／R6（CustomerStatus/OrderStatus 遷移バリデーション・04 R6） |
| F-6 | UAT（実業務担当者） | ⬜ R8。`business-flow-analysis` の 9 工程をベースに、社内管理者/代理店/営業担当者/顧客マイページのロール別シナリオ |
| F-7 | 負荷・性能テスト | ⬜ R8（J と連動） |
| F-8 | カバレッジ目標 | ❓ 未定（Q-10。旧「Pest/カバレッジ」→ Rails 版は RSpec 確定・カバレッジ目標値のみ未決。simplecov 未導入） |
| F-9 | CI での DB 検証 | ✅ 実装済み: CI test ジョブが **PostgreSQL 16 + pg_bigm コンテナ**で `db:schema:load` → rspec。**未対応: `db:migrate` → `db:rollback` → 再 `db:migrate` の smoke**（旧 F-9 の MySQL 8.4 検証は不要）→ R8 で追加 |
| F-10 | Pundit 呼び出し漏れの機械検出（Rails版で追加） | ⬜ 未着手: `after_action :verify_authorized` / `verify_policy_scope` が `ApplicationController` に無い（04 R0 見送り事項）。CI の grep ガードより確実なため R5 着手前に導入推奨 |

---

## G. 法務・コンプライアンス 🔴 — R8（**今から並行**）

| # | 項目 | 出所 / 状態 |
|---|---|---|
| G-1 | 決済フローの法務確認 | ⬜ 未着手（旧 `remaining-tasks.md` 8-2 = 削除済み・旧Laravel側に残存。内容は本行に保持） |
| G-2 | 情報システム室へのリスク連携（**ガルーン連携 Q-G2 も含む**） | ⬜ 未着手（旧 8-1）。本番構成（Q-40）、DNS/メール送信、DB/ストレージ、監視/バックアップ、個人情報保管場所 |
| G-3 | 利用規約・重要事項説明の内容確定 | ⬜ `business-flow-analysis` §1 |
| G-4 | 個人情報保護方針・取り扱い | ⬜ 同 §0 / `pii-handling-rules.md`（Q-A） |
| G-5 | 特定商取引法に基づく表記 | ⬜ D-5 |
| G-6 | 電子契約・電子文書の法的要件（電子帳簿保存法等） | ⬜ D-4。署名・重要事項説明・確認書・契約書の同意証跡/版管理/改ざん防止（R5 設計に反映） |
| G-7 | 委託先（アシスト・アイフラッグ）との情報連携の契約・範囲 | ⬜ `business-flow-analysis` §8 |
| G-8 | 原資料の秘匿情報の取り扱い | ❓ 同 §0 / Q-A |
| G-9 | メール送信運用の法務/運用確認 | ⬜ 送信元表示、問い合わせ先、配信停止要否、迷惑メール対策、添付文書の扱い（A-12 と連動） |

---

## H. 運用・サポート体制 🟠 — R8

| # | 項目 | 状態 |
|---|---|---|
| H-1 | 操作マニュアル（アプリ内 Web 提供＋生成の仕組み） | ⬜ 未着手（旧 P5-4。**04 に対応タスク無し → R8 に追加要**）。対象読者は顧客まで全対象（Q-20/D-7）。ftlog のマニュアル機構を一次情報として移植 |
| H-2 | バックヤード作業マニュアル | ⬜ 未着手（旧 `remaining-tasks.md` 6-1 = 削除済み。内容は本行に保持。**04 に対応タスク無し**） |
| H-3 | 問い合わせ対応フロー | 🔶 機能は R4 実装済み（Inquiry / ルーティング / メール送信）。運用設計・返信テンプレート（FAQ 318件・04 R4 未実装ギャップ）は未 |
| H-4 | 移行後の並行稼働・現行停止の判断 | ⬜ B-9 |
| H-5 | 代理店・営業への教育・移行案内（共通→個別アカウント） | ⬜ 未着手（R8）。旧環境停止告知、新URL案内、ログイン方式変更（代理店CD＋営業担当者CD＋メールOTP）案内、停止時間周知 |
| H-6 | 障害時の業務継続手順 | ⬜ 未定義（R8）。決済障害（Q-27）、メール送信障害、ストレージ障害、DB 障害、旧環境切り戻し、リクリック連絡不能時 |

---

## I. リリースプロセス 🟠 — R8

| # | 項目 | 状態 |
|---|---|---|
| I-1 | リリース方式（一括/段階） | ❓ 未確定（Q-2）。リクリック当日作業合意と移行リハーサル実測後でないと確定不可 |
| I-2 | カットオーバー手順書 | ⬜ 未作成（B-9）。旧環境停止→リクリック最終退避→整形（rake ETL）→新環境投入→検証→公開 の直列手順 |
| I-3 | ロールバック手順 | ⬜ 未定義。アプリは `kamal rollback`（採用時）、DB は E-4 のリストア、旧環境切り戻しはリクリック依頼ルート（N-1-e） |
| I-4 | リリース判定基準（Go/No-Go） | ⬜ **本書がその原型**。移行リハーサル、法務、決済、本番構成、監視、UAT、切り戻し合意に担当・期限を割り当てる |
| I-5 | リリース後の初期監視（ハイパーケア） | ⬜ 未定義 |
| I-6 | 本番初期データ投入（Rails版で追加） | 🔶 `db/seeds.rb`（`RoleSeeder` / `StatusSeeder`）と起動時 `permissions:sync` で権限カタログ・組み込みロール・ステータスは自動投入。**OptionGroup（属性1-11 等）・BRIDGE_PLUS フォームテンプレート・FAQ テンプレートの初期データ投入手段は未**（旧 P2-5/P2-8。R7 or R8） |

---

## J. 性能・可用性 🟡 — R8

| # | 項目 | 状態 |
|---|---|---|
| J-1 | 想定同時接続・ピーク負荷 | ⬜ 未把握（旧 `basic-cost.md` は〜50ユーザ）。負荷試験で確認 |
| J-2 | 一覧・検索のページング | 🔶 pagy 8 系で主要一覧は対応済み。**Store 一覧に検索・ページネーション無し**（04 R2 見送り事項）。カーソル方式は未採用（必要なら大量テーブルのみ） |
| J-3 | N+1 クエリ点検 | ⬜ 未実施（bullet 未導入。R8 で点検） |
| J-4 | CSV 等の重処理の負荷（掲示板42万件の移行含む） | ⬜ 未検証。Solid Queue の処理能力（DB ポーリング）、ストレージ転送、メール送信量 |
| J-5 | 可用性目標（SLA） | ⬜ 未定義 |
| J-6 | DB 接続数・インデックス | ⬜ 未検証。4 DB 構成の接続数（A-10）、pg_bigm インデックスの適用箇所、検索/一覧/CSV/ETL |

---

## 追加すべき共有資料（依頼リスト）

| # | 資料 | 用途 | 状態 |
|---|---|---|---|
| M-1 | 決済API仕様書 | R5 着手 | ✅ 資料内にあり（ネットムーブ・`legacy-research/02`） |
| M-2 | 現行DBスキーマ・データ | データ移行（R7） | ✅ 資料内にあり（DB退避CSV） |
| M-3 | 顧客詳細フィールド定義 | R2（実装済み） | ✅ 実質解消（155項目＋現行仕様書） |
| M-4 | 発注CSV注意事項xlsx | R6（P4-12） | 存在確認済（未精読） |
| M-5 | 現行申込フォーム実画面 | 155項目の確定（R3 突合） | 一部（申込書PDFあり） |
| M-6 | 契約書・申込書PDFサンプル | R5（P3-8） | 申込書控えPDFあり |
| M-7 | 利用規約・重要事項・特商法の現行文面 | 法務（G） | 未 |
| M-8 | 現行メールテンプレート | R4（実装済み・文面精査は未） | 一部（業務フロー資料に全文あり） |
| 残 | ネットムーブ開通処理・HMACキー・商用カード検証方法 | R5 / D-1 | ネットムーブへ要確認。検証専用環境は無い可能性あり |

---

## リリースまでのマイルストーン（Rails版）

```
■ M1（達成）：基盤 + 組織 + CRM中核 + 申込フォーム + 問い合わせ/通知 = R0〜R4
  参照制御（Pundit）・監査ログ・ログイン履歴・IP許可リスト・全画面メールOTP を含む
■ M2：契約フロー完成 = R5
  決済・署名・不備・差戻し・確認コール・契約書。着手前ブロッカー = Q-25〜27・Q-35〜39・Q-D
■ M3：本番リリース = R8（+ R7 データ移行）
  本書 A〜J。B（データ移行・R7）と G（法務）・D-1（本番接続審査）は今から並行
```

> **注意**：A〜J を M3 にまとめると破綻する。**データ移行（B/R7）・法務（G）・ネットムーブ本番接続審査（D-1）は R5 と並行**で動かす（04 R8 完了条件「少なくとも法務(G)・本番審査(D)は着手済み」）。

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版作成。10領域（A〜J）で整理。共有資料の依頼リスト（M-1〜）を作成 |
| 2026-07-24 | 資料調査を反映：M-1（決済API）・M-2（現行DB）・M-3 が資料内で解消。B にデータ移行の整形（`legacy-research/09`）を反映、B-3a（CSV破損是正）追加 |
| 2026-07-27 | requirements横断見直しを反映。Q-C/Q-B/Q-22/MySQL 8.4/カットオーバーN-1/AWS/SES/PII/監視/Go-No-Go/UATのチェック項目を更新 |
| 2026-08-19 | **Rails版へ全面改訂**（brige-crm へ集約後）。基盤スタックの正を 03§2 と明記。A-1 の MySQL 8.4 決定を「Laravel側限定の旧決定」として PostgreSQL 16 へ置換。Redis/Horizon/Reverb/SES/S3/TrustProxies を Solid Queue/Cache/Cable・ActionMailer SMTP・Active Storage・`RemoteIp`/`assume_ssl` へ読み替え。CI 実態（brakeman/bundler-audit/importmap audit/rubocop/rspec on PostgreSQL 16/authorization_guard）を反映。全項目に状態ラベル（実装済み／部分実装／未着手（R8）／要決定）を付与。Rails 版で追加: A-14 Ruby版差異、C-13 セッション/Cookie ハードニング、C-14 ログマスク、D-8 決済キュー隔離、D-9 会員ID引継ぎ、E-10 監査ログ画面、F-10 Pundit verify、I-6 初期データ投入。削除済みファイル（`basic-cost.md` `remaining-tasks.md` `ftlog-port.md`）への参照を差し替え |
