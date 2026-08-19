# レビュー: 02-ftlog-architecture-analysis.md 事実検証

- レビュー対象: `projects/brige-crm/requirements/design/02-ftlog-architecture-analysis.md`（2026-08-14作成）
- 検証方法: 記載内容を `projects/ftlog/` の実ソース（Gemfile / Gemfile.lock / app 配下 / db/schema.rb / spec / .github/workflows/ci.yml 等）と1つずつ突合。推測は含まない
- レビュー実施: 2026-08-15（CTOペルソナ）
- 前提: R0で本RBACを実際にコピー移植する作業者が読む前提。誤りの指摘に加え、移植時に詰まりそうな暗黙の前提・依存ファイルを積極的に指摘する

---

## ✅ 確認済み（正確だった主張・代表例）

- **§1 技術スタック**: Ruby 3.4.4（`.ruby-version`）/ Rails 8.1.3（`Gemfile.lock:316`）/ pg_bigm（`db/migrate/20260708000002_enable_pg_bigm_and_add_search_indexes.rb`, `db/Dockerfile`）/ Devise・Pundit・acts_as_tenant・solid_cache/queue/cable・rack-attack・aws-sdk-s3+image_processing+rubyzip・kamal（すべて`Gemfile`に存在）/ kaminari・pagy不在（`Gemfile`にgemなし）/ docker-entrypointでの`permissions:sync`自動実行（`bin/docker-entrypoint:4-9`）— すべて正確
- **§2-1 RBAC 4テーブル**: `system_permissions`のUNIQUE(controller,action,http_method,path)（`app/models/system_permission.rb:19,34`）、`system_roles`のUNIQUE(organization_id,name)（`system_role.rb:20,73`）、`system_role_permissions`のUNIQUE(system_role_id,system_permission_id)（`system_role_permission.rb:13,26`）、`user_system_roles`のUNIQUE(user_id,system_role_id)+組織一致バリデーション（`user_system_role.rb:15,26-39`）、組み込み6ロール名と対応フラグ（`system_role.rb:36-63`のBUILT_IN_ROLE_ATTRIBUTES）まで一字一句正確
- **§2-2 リクエストフロー**: `application_controller.rb:7-14`のbefore_action順序（authenticate_user! → ensure_user_is_active → set_current_attributes → redirect_customer_to_portal → authorize_system_permission!）が記載順と完全一致。`authorize_system_permission!`本体（同48-58行）も擬似コードと論理構造が一致。テナント解決フォールバック順（同77-81行）も正確
- **§2-3 SystemPermissionChecker**: `app/services/system_permission_checker.rb`のsuper_adminバイパス（14-17行）、matching_permissionsのhttp_method: [http_method, "ALL"]（52-58行）、staff/customerのsection分離ロジックが記載通り
- **§2-4 SystemPermissionSyncService**: find_or_initialize_by冪等生成（`system_permission_sync_service.rb:46-61`）、非アクティブ権限のenabled:false化（64-69行）、`portal/`始まりの自動section判定（119-121行）が正確
- **§2-5 OrganizationRoleSeeder**: `grant`メソッドが既存分をpluckして差分のみ追加し剥奪しない実装（`organization_role_seeder.rb:149-155`）で「追加のみ」の主張を裏付け。project_adminの集合演算例（109-112行）も記載通り
- **§2-7 管理UI**: `permission_management_controller.rb`のupdate_role_permissions!がトランザクションで差分create/destroy（38-56行）、admin_rolesを編集対象から除外（36,39行）— 「super_admin列は編集不可」の主張を裏付け。`role_management_controller.rb`のsystem?ロールでname除外（61-66行）も正確
- **§2-8 ビュー例**: `app/views/comments/_comment.html.erb:17`に`can_access_system_action?("comments", "destroy", http_method: "DELETE") && policy(comment).destroy?`がほぼ逐語一致で実在
- **§3 認証**: Devise modules（`:database_authenticatable, :registerable, :recoverable, :validatable, :lockable, :timeoutable` — `user.rb:46-47`）、OTP実装（otp_code_digest=SHA256, 10分, 5回上限, secure_compare — 同63-65,167-192行）、`warden.authenticate!(store: false)`（`users/sessions_controller.rb:14`）、rack-attackでのOTP/パスワードリセット制限（`config/initializers/rack_attack.rb`）、deliver_later（`user.rb:154`）、招待制・公開登録ブロック（`users/registrations_controller.rb:8-11`）すべて正確
- **§4 アプリ構造**: forms/・decorators/不在、controllers/の名前空間（platform_admin/portal/projects/users）、concerns（Auditable/AuthAuditable/UserAdminAuditable/CustomSignInRedirect/WikiFeatureGuard）すべて実在確認
- **§6 テストハーネス**: `spec/support/system_permission_authorization.rb`の既定=実認可・`:skip_system_authorization`タグでのスタブ・`:seed_permission_catalog`タグでのSyncService実行・`grant_system_permissions!`ヘルパー、いずれも記載通り実装されている
- **§末尾 主要参照ファイル一覧**: 列挙された15ファイルすべて実在を確認（`app/models/current.rb`, `permission_management_controller.rb`, `role_management_controller.rb`, `permission_management/index.html.erb`, `system_permission_authorization_spec.rb`含む）
- **§7 単一テナント簡素化の妥当性**: `projects/brige-crm/requirements/design/03-rails-architecture-proposal.md:15`で実際に「acts_as_tenantは移植しない」「単一テナント前提」が決定者決定済み。02の提案方向性は後続の03決定と整合しており、技術判断として妥当だったことが裏付けられる

---

## ⚠️ 誤り・要修正

1. **§5「業務系」テーブル一覧に存在しない`customers`テーブルが記載されている**
   - 実際にはCustomerは`User`のSTIサブクラスであり、`users`テーブルの`type`カラムで表現される。独立した`customers`テーブルは存在しない
   - 根拠: `projects/ftlog/db/schema.rb`に`create_table "customers"`は無い。`projects/ftlog/app/models/customer.rb:1-4`のスキーマ注釈も`# Table name: users`と明記
   - 影響: 軽微に見えるが、R0で「customersテーブルを作る」という誤読を招きかねない。02は`users`テーブルのSTI設計（§2-1末尾の「UserはSTI」の一文はあるが§5では反映されていない）との整合を取るべき

2. **§5「業務系」テーブル一覧に存在しない`login_histories`テーブルが記載されている**
   - 実際には専用テーブルは無く、`LoginHistoriesController#index`が`AuditLog`を`AuthAuditable::AUTH_ACTIONS`でフィルタして表示する画面（監査ログの絞り込みビュー）に過ぎない
   - 根拠: `projects/ftlog/db/schema.rb`に`create_table "login_histories"`は無い。`projects/ftlog/app/controllers/login_histories_controller.rb:6,11-12`で`scope = AuditLog.where(organization_id: org.id, action: ACTIONS)`と実装されている
   - 影響大: `projects/brige-crm/requirements/design/03-rails-architecture-proposal.md:90`にも「ログイン履歴（login_histories）...もftlogから移植可」と記載があり、**同じ誤解が03に伝播している可能性がある**。R0着手前に03側も含めて「login_historiesは別テーブルではなくAuditLogの絞り込みビュー」である旨の訂正を推奨

---

## ➕ 不足・追加すべき情報（移植時に詰まりそうな暗黙の前提）

1. **SystemPermissionSyncServiceのaction単位除外（EXCLUDED_ACTIONS）が完全に欠落**
   - `system_permission_sync_service.rb:19-24`には`EXCLUDED_CONTROLLER_PREFIXES`（controller単位）とは別に`EXCLUDED_ACTIONS`（controller+action単位。project_filesのマルチパートアップロード系アクションを除外）が存在する。02 §2-4は前者しか説明しておらず、除外がcontroller粒度だけでなくaction粒度でも必要になりうることが読み取れない。brige-crmでも将来同様の「内部API的アクション」が出た場合に見落とす

2. **EXCLUDED_CONTROLLER_PREFIXESの完全なリストが「等」で省略されている**
   - 実際は`active_storage/ rails/ devise/ platform_admin/ turbo/ manual portal/manual portal/faq`の8項目（`system_permission_sync_service.rb:6-15`）。brige-crmは3区分（admin/form/mypage）に拡張するため、区分ごとの除外リストを設計時に再定義する必要がある。「等」で済ませず全項目を移植計画に含めるべき

3. **SEALED_CONTROLLERSはstaff用とportal用の2系統ある**
   - `organization_role_seeder.rb:76-84`に`SEALED_CONTROLLERS`（staff側：wiki_pages, wiki_page_comments）と`SEALED_PORTAL_CONTROLLERS`（portal側：portal/wiki_pages, portal/wiki_page_comments）が別定数として存在し、customer権限付与のwhere.not（146行）にのみ後者が使われる。02は単一の「SEALED_CONTROLLERS」としか書いておらず、staff/customer二系統の並行メンテナンスが必要な設計であることが伝わらない

4. **SYSTEM_ADMIN_ONLY_CONTROLLERSの完全なリストと非自明な理由が省略されている**
   - 実際は10項目（`organization_role_seeder.rb:60-71`）で、`customer_management` `ip_allowlist_entries` `login_histories` `issue_templates`のようにドメイン知識が無いと理由がわからない項目を含む。特に`ip_allowlist_entries`がSA専有な理由は「project_adminが自分の接続元IPを許可リストに登録すると二要素認証を回避できてしまうため」というセキュリティ上の教訓（同57-59行のコメント）で、これは02の「role/permission管理・監査ログ・組織設定 等」という要約には出てこない。brige-crmで同種のSA専有リストを再定義する際にこの種のセキュリティ根拠を引き継がないと同じ穴が再発しうる

5. **`SystemRole#prevent_destroy_if_default_role`（暗黙のcrossモデル依存）が未記載**
   - `system_role.rb:122-128`に「`organizations.default_system_role_id`が参照しているロールはFK制約により削除できない」ガードがある。単一テナント簡素化でSystemRoleのorganizationスコープを外す際、この防御をどう扱うか（default_system_role_id自体を廃止するのか、別の形で残すのか）が02 §7「移植時の注意」に含まれていない

6. **テストハーネスの実体は`system_permission_authorization.rb`だけでなく`fail_open_request_specs.txt`とCIジョブの3点セット**
   - `spec/support/fail_open_request_specs.txt`（`system_permission_authorization.rb:19`が参照する許可リストファイル）と、`.github/workflows/ci.yml`の"Detect fail-open allowlist growth"ステップ（約198-227行、許可リストがshrinkのみ＝新規追加を機械的に拒否するガード）は、02 §6でも「主要参照ファイル」一覧でも触れられていない。この2つが無いとフェイルオープン件数が野放しに増える「回帰検出の要」（02自身が★★★と評価する部分）が機能しない。R0で移植すべき最小セットに追加すべき
   - 併せて`system_authorization`タグ（`system_permission_authorization.rb:56-58`。許可リスト内の旧specでも明示的に実認可へ強制するオプトアウトの逆）も02 §6は未記載

7. **`permissions:sync`の自動実行条件は「サーバー起動時」限定**
   - `bin/docker-entrypoint:4`は`./bin/rails server`起動時のみsyncを実行する条件分岐であり、`rails console`や単発の`rails runner`実行では走らない。02の「起動時に自動実行」という表現は本番runbookで誤解（「コンテナを立ち上げれば常に同期される」という誤解）を招きうるため、条件を明記すべき

---

## ❓ 要決定者確認・未決事項

1. **02は03の意思決定より前のスナップショットとして扱われているか**: `03-rails-architecture-proposal.md`では既にsection数を2→3（admin/form/mypage）に拡張し、OrganizationRoleSeederを組織スコープなしの`RoleSeeder`に単純化する方針まで確定している（決定は2026-08-14）。02はその参考資料として作られた経緯上、内容が03と矛盾しない限り更新不要と考えるが、上記⚠️の`login_histories`誤解が03側（90行目）にも伝播している可能性があるため、**03の該当記述も合わせて確認・訂正するか**は決定者判断を仰ぎたい
2. **本レビューで見つかった➕の情報を02本体に反映するか**: 今回の権限（読み取り自由・書き込みはreviewファイルのみ）の範囲では02は変更していない。EXCLUDED_ACTIONS・SEALED_PORTAL_CONTROLLERS・fail_open_request_specs.txt等をR0着手前に02へ追記するか、もしくは03/04側で直接手当てするかの方針決定が必要
3. **`ip_allowlist_entries`のSA専有ルール（2FA回避防止）のような「歴史的教訓」をbrige-crmでどう継承するか**: brige-crmには2FA自体は移植予定（03 §4）だが、同種の「PAが自分に有利な設定を入れて認証を弱める」経路が無いかは新規に洗い出しが必要。02のレベルではこの種の教訓が要約で失われているため、原典（`organization_role_seeder.rb`のコメント群）を読む工程をR0タスクに明示すべきか確認したい

---

## サマリ

10項目すべてを実ソース突合で検証。§2〜§4・§6・§7の中核記述（RBAC 4テーブル、リクエストフロー、Checker/SyncService/RoleSeederのロジック、テストハーネス、参照ファイル一覧、単一テナント簡素化の妥当性）はいずれも実装と一致しており、02の技術的信頼性は総じて高い。
