# brige-crm 実装計画（v5）

- 前提: 03-rails-architecture-proposal.md の構成（**論点A〜F はCEO決定済み 2026-08-14**: PostgreSQL / Hotwire+ERB / section3区分 / prefix除去 / rails new+選択移植 / 移行別フェーズ）
- 方針: Laravel の P0〜P4 フェーズ構成を踏襲しつつ、**認可・参照制御・監査を最初のフェーズに前倒し**する
  （Laravel側で「後付けは手戻り大」と分析された箇所を先に固める）
- 状態: **v5（R5着手前チェックリストのCEO決定を反映）**。**R0〜R4 実装完了**。次アクション=CTO判断で即着手可能な項目（R0/R2/R3残・下記「次のアクション」6）に着手し、R5-1 契約ワークフロー状態機械の設計へ進む
- **2026-08-15 CTO洗い直し反映**: 01/02/03との突合レビュー（`review/review-01〜04-*.md`）を受け、網羅性の漏れ（P3-11・掲示板Inquiry拡張・IP許可リスト）とR8新設を本文に反映。決定D（Customer命名）衝突・Q-23（全画面2FA）・formセクションのRBAC統合方式は、CEO不在のためCTO自律決定（03§8-2参照）で解消しR0〜R4着手。誤りがあれば事後にCEO確認・訂正する。
- **2026-08-19 設計ドキュメント一元化**: 旧Laravelプロジェクト（`boilerplate-vue-env/laravel/requirements/`）の設計ドキュメント31ファイルを本リポジトリへ集約し、全件精査（`review/review-05-legacy-design-docs-sweep.md`）。これにより「リスク・注意4（要件の正をどちらのリポジトリで持つか）」は解消し、**以後 requirements/ の正はbrige-crm側**とする。
  - 精査の結果、Laravel固有・実装済みで役目を終えた7ファイル（`Inquiry-email.md` `ftlog-port.md` `basic-cost.md` `branch-merge-policy.md` `test-code-plan.md` `test-file-review.md` `remaining-tasks.md`）は本リポジトリへは持ち込まず削除した（旧Laravel側には残存。必要時に再参照可）。本文中の当該ファイルへの参照は代替先へ差し替え済み。
- **2026-08-19 設計ドキュメント Rails版改訂（v4）**: 集約した全設計ドキュメント（`design/` 24ファイル + `legacy-research/` 16ファイル + `development-plan.md`）を、**現行実装（`db/schema.rb`・`app/`）と03/04の決定に合わせて全面改訂**した（9グループ並列。集約サマリ=`review/review-06-rails-revision-sweep.md`）。各設計書に「実装済み／差分／未実装（Rx）」の突合注記と改訂ヘッダを付与し、Laravel固有記述をRails等価物へ置換。**この突合で新たに判明した実装ギャップ・未決論点・タスクを本文の各フェーズへ反映**した（「2026-08-19 v4追記」箇所）。併せて `p3-12-13-confirmation-docs.md`→`contract-confirmation-docs.md`、`notification-matrix-draft.md`→`notification-matrix.md` へリネーム。
  - `development-plan.md` は「全体像・P→R対応表・未決定事項台帳（Q-xx全件）・変更履歴」の入口として再定義し、**フェーズ詳細の正は本書（04）**とした。
  - `Column.md` は schema.rb と全テーブル機械突合済み（§0共通規約・§12実装のみのテーブル37・§13未実装テーブル・§14突合表を追加）。**以後「Column.md は schema.rb に追従」を運用ルールとし、マイグレーション追加時に Column.md 更新を必須とする**。
- **2026-08-19 CEO決定（v5・R5着手前チェックリスト回答）**: v4で洗い出したR5着手前ブロッカーのうちCEO判断が必要な8論点についてCEOへ選択式で確認し、全件決定した。決定内容は各フェーズ節（R2/R3/R4/R5）の該当箇所に反映済み。要約:
  - **DM-6（案件初期ステータス）**: 現状維持（`orders.status` 既定値「0:受注」をそのまま使う。実装変更なし）
  - **R4追補（RecipientResolver 合成規則）**: 修正する。`is_visible_to_agent`・ステータス等の見える範囲に応じて代理店・顧客への自動送信を絞る
  - **Q-D-3（分類C PIIの暗号化）**: 平文のまま（アクセス制御・監査ログで守る。`netmove_member_id` 等は暗号化しない）
  - **G-1/G-9（商材別納品日）**: **現状維持**（1案件=1納品日のまま。スキーマ変更なし）。旧D-4（2026-07-26「商材は増える見込み→別テーブル化」）と矛盾していたため2026-08-19に再確認し、CEOが現状維持を明示的に優先・確定（development-plan.md Q-F を更新）
  - **Q-25（返金・キャンセル）**: 状態記録のみ（実際の返金処理は制度外・手作業/決済代行会社の管理画面で対応）
  - **Q-26（信販）**: 対象外（支払方法の選択肢に含めない）
  - **Q-27（決済障害時の縮退運用）**: 一時保留して手動対応（自動リトライは実装しない。既定方針と整合）
  - **E3/E5/E6（通知宛先）**: E3差戻し=営業担当者・社内実務担当者（顧客へは通知しない）／E5契約確定=顧客（契約書メールと同時）・営業担当者・社内実務担当者／E6決済失敗=**通知不要**（営業担当者と顧客がWeb商談でオンライン中に顧客が画面上でカード情報を入力して決済するため、失敗はその場で画面表示され非同期通知は不要）
  - **FAQテンプレート機能**: 実装する。R6（運用強化フェーズ）で着手
  - **顧客本人入力導線**: 営業担当者が入力して仮申込を作成→顧客にメールでリンク送付→顧客がそのリンクから申込を再開するハイブリッド方式を採用（R5で実装）
  - 未回答（引き続き保留）: Q-35（重説チェック・確認書のQ-1〜9詳細）、Q-36〜39（決済トランザクション技術仕様・ネットムーブ回答待ち）

---

## 設計ドキュメント一覧（Rails版改訂済み・フェーズ対応）

| ファイル | 役割 | 主フェーズ | 状態 |
|---|---|---|---|
| `01〜03-*.md` | Laravel分析／ftlog分析／アーキテクチャ決定録 | 全体 | 確定 |
| `04-rails-implementation-plan.md`（本書） | フェーズ計画の正 | 全体 | v4 |
| `../development-plan.md` | 全体像・P→R対応表・未決定事項台帳（Q-xx）・履歴 | 全体 | Rails版 |
| `basic-design.md` | 機能仕様の正（18章。§1-5/15-18=R0〜R4実装済み、§6-14=R5） | R0〜R5 | 突合済み |
| `Column.md` | スキーマ設計の正（schema.rb追従） | R1/R2（R5/R6は§13） | 突合済み |
| `form-template-mapping.md` | 申込フォームのフィールドマッピング（§9 実装突合表） | R3 | 突合済み |
| `pii-handling-rules.md` | PII 3分類ルール・Q-D決定待ち事項（§5） | R2/R5/R7/R8 | 突合済み |
| `board-implementation-options.md` | 掲示板→Inquiry統合（決定D-11。§0 実装突合） | R4/R7 | 突合済み |
| `notification-matrix.md` | 通知受信者マトリクス（E1〜E13 実装済みルール列） | R4/R5/R6 | 突合済み |
| `status-naming-analysis.md` | ステータス呼称（Q-B/D-8。§0-1 適用状況・§4-1 修正ファイル一覧） | R2/R5 | 突合済み |
| `payment-integration.md` | ネットムーブ決済連携設計（§4-10 Rails版配置・§5 テーブル） | R5 | 設計 |
| `netmove-card-migration.md` | 会員ID/カード情報引き継ぎ | R5/R7 | 設計 |
| `contract-confirmation-docs.md` | 重説チェック・申込確認メール/確認書（旧P3-12/13） | R5 | 設計 |
| `customer-merge-design.md` | 顧客名寄せ（§8 request spec S-1〜S-8） | R6 | 設計 |
| `export-profile-design.md` | CSV複数プロファイル（P4-12。§7 R5請求用CSVの位置づけ） | R5/R6 | 設計 |
| `business-flow-analysis.md` | 業務フロー分析（G-1〜G-10 Rails版判定・§7 請求ルール） | R5/R6 | 突合済み |
| `name-matching-process.md` | 掲示板投稿者名寄せ手順 | R7 | 設計 |
| `release-readiness.md` | リリース準備チェックリスト A〜J（状態ラベル付き） | R8 | 突合済み |
| `legacy-research/00〜15` | 旧システム調査ノート・移行一次資料（11=238フィールド突合 付録A） | R7 | 突合済み |
| `review/review-01〜06` | レビュー記録 | — | 記録 |

---

## フェーズ概要

| フェーズ | 内容 | Laravel対応 | 完了条件（要約） |
|---|---|---|---|
| R0 | 基盤: rails new・Docker・CI・認証・**認可RBAC移植**・監査ログ | P0 + ftlog移植 | 認可ゲート/テストハーネス/CI が回る |
| R1 | 組織・アカウント: 代理店G/代理店/営業担当者/契約条件/ユーザ管理 + **Punditスコープ** | P1前半 | 参照制御込みでCRUD一式 |
| R2 | CRM中核: 顧客/店舗/案件 + 商材マスタ群 | P1後半 | 案件90フィールド・ステータス管理 |
| R3 | 申込フォーム: 営業ログイン・動的マルチステップ・一括生成 | P2（拡張後仕様） | フォームビルダー含め動的マッピングで動作 |
| R4 | 問い合わせ・通知: Inquiry系・一斉通知・アプリ内通知・CSVエクスポート | P1残 + P4-8 | リアルタイム通知含む |
| R5 | 契約フロー・決済: 状態機械・ネットムーブ連携・契約書PDF・署名 | P3（新規実装） | 決済サンドボックス疎通・契約状態機械spec |
| R6 | 運用強化: 名寄せ・一括更新・集計・遅延検知ほか | P4 | 要件ごとに個別判断 |
| R7 | データ移行: ETL・掲示板アーカイブ | P5相当 | 別プロジェクト切り出し（決定F） |
| R8 | 品質保証・リリース準備: デプロイ/CI-CD・カットオーバー計画・監視ログ・法務・本番接続審査・運用教育・UAT/性能診断 | P5（release-readiness.md A〜J） | release-readiness.md A〜Jが着手済み、少なくとも法務(G)・ネットムーブ本番審査(D)は着手済み |

---

## R0: 基盤（最重要フェーズ）

1. `rails new`（Rails 8.1 / PostgreSQL / UUID主キー既定 / rubocop-rails-omakase）
2. Docker整備: db(pg16+pg_bigm) / web / tailwind(watch) / worker(Solid Queue) / mailpit
3. フロント基盤: Hotwire（importmap-rails + propshaft + turbo-rails + stimulus-rails）+ Tailwind CSS v4（tailwindcss-rails・Nodeレス）。ftlogのレイアウト・共通パーシャルを流用
4. 認証: Devise（User）+ ftlog式メールOTP + rack-attack + ログイン履歴（AuditLogの絞り込みビュー。専用テーブルではない） + **IP許可リスト**（P4-17。空リスト=全員OTP必須のフェイルセーフを踏襲。※出典だった`ftlog-port.md`は2026-08-19に削除済み。ftlog本体の実装が一次情報）
   - 2026-08-15 CTO決定（03§8-2）: Q-23（D-5・全画面2FA必須）に準拠する。R0時点ではCustomer/SalesRepresentativeモデルが存在しないため、**メールOTPロジックをUser専用実装ではなく再利用可能なconcern/serviceとして切り出し**、R3(form)・R4(mypage)がそれぞれの認証フローに組み込めるようにしておく
5. **認可: ftlogエンドポイントRBAC一式を移植**（単一テナント簡素化）
   - 4モデル + SystemPermissionChecker + SystemPermissionSyncService（起動時sync）+ RoleSeeder
   - ApplicationController フェイルクローズゲート
   - 組み込みロール: admin(super_admin) / 実務運用者 / 代理店グループ用 / 代理店用（名称維持）
   - 権限マトリクスUI・ロール管理UI
   - 2026-08-15 CTO決定（03§8-2）: 受注入力（form）はDevise/STI対象外につき`authorize_system_permission!`を完全スキップし、独自FormAuthミドルウェアのみで保護する方式(b)を採用
6. Pundit 導入 + ApplicationPolicy 規約（Scope#resolve 必須）
7. 監査ログ: ftlog Auditable concern 移植（TRACKED_FIELDS / request_id / IP / 差分記録）
8. `Current`（user/ip/request_id）+ created_by/updated_by 自動セット
9. テスト基盤: RSpec + FactoryBot + **認可テストハーネス**（既定=実認可）
10. CI: rubocop / brakeman / bundler-audit / rspec / 認可スキップ検出grep

**R0完了条件**: ダッシュボード1画面が「ログイン→OTP→権限チェック→表示」を通過し、権限を剥奪すると403相当になる request spec がグリーン。**加えて、このログイン・権限チェックイベントが監査ログ（Auditable concern）に記録されていることをspecで確認**（2026-08-15追記: 項目7監査ログが完了条件から漏れていたため）。

**R0見直しレビュー残タスク（2026-08-17追記）**: R0〜R3の総見直しで、`bin/docker-entrypoint`の起動時sync漏れ・権限拒否イベントの監査ログ未記録・IP許可リストOTP免除の管理画面/フォーム画面非対称の3件は発見・是正済み（commit `3bb033f`）。加えて以下は見直し時に発見したが機能追加に近く深夜の無人修正は見送ったもの:
- `ApplicationController`に`after_action :verify_authorized`/`verify_policy_scope`（Pundit標準の安全網）を追加する。現状これが無く、R2以降で`policy_scope`/`authorize`の呼び出し漏れを機械的に検出できていない（項目10「CIの認可スキップ検出grep」も文字列マッチのみで脆弱）。verify系フックの方がCIのgrepより確実。**→ 2026-08-19 v4: R5着手前チェックリストへ格上げ**（release-readiness.md F-10 / development-plan.md T-11）。

**R0 追加タスク（2026-08-19 v4追記）**:
- **rack-attack スロットルの適用範囲拡張**: 現状 `/users/password` `/users/otp*` のみで、`/users/sign_in`・`/form/login`・`/form/otp`・`/mypage/login`・`/mypage/otp` が未適用（代理店CD＋営業担当者CD の総当たり対策が無い）。R5着手前の小改修として実施（出典: `release-readiness.md` C-6、`basic-design.md` §2-3）。
- マイページ側は IP許可リストによる OTP 免除を適用していない（意図的な非対称）。方針として妥当かをCEO確認（`basic-design.md` §2-4）。

## R1: 組織・アカウント

- AgencyGroup / Agency / SalesRepresentative / ContractCondition / User のCRUD
- 是正を織り込む: sales_rep_code グローバルユニーク（T-2）、契約条件は受注紐づけ前提のスキーマ（T-3）
- **Pundit policy_scope で「代理店=自代理店のみ・グループ=配下のみ」を全一覧・詳細に適用**（P4-1先取り。以降の全エンティティで必須）
- ユーザCSV一括アップロード（非同期ジョブ）
- 販売許可（Product×Agency/AgencyGroup 中間）はR2でProductと同時に

**R1見直しレビュー残タスク（2026-08-17追記）**: Agency/AgencyGroup削除時のユーザー権限昇格バグ（`dependent: :nullify`起因、重大）とCSVインポート全体パース失敗時の無言失敗は発見・是正済み（commit `1e7a0ad`）。加えて以下は見送り:
- CSVインポート結果の可視化・履歴永続化。`UserCsvImportJob`は成功/失敗件数を`Rails.logger`にしか残さず、どの行が・なぜ失敗したかを管理者がUIから確認する手段が無い。同じCSV機能である`CsvExport`（`status`/`error_message`/`row_count`列あり）と対称的な`UserCsvImport`モデル（または既存テーブルの汎用化）を追加し、`import.html.erb`に直近インポート履歴を表示する対応を推奨。

**R1 要確認（2026-08-19 v4追記）**:
- `agencies` に住所・電話カラムが無い（Q-移7）、旧システムの「施工担当者」概念が無い（DM-7）— R7 の移行要否と一体でCEO確認（`legacy-research/08`）。
- `sales_representatives.email` は受注入力OTPの送信先だが NULL 可・旧CSVに列が無い（Q-移19）。運用上必須にするなら validation 追加（`Column.md` §7）。
- 実務運用者ロールの「一部制限あり」の業務定義が未確定（現状は社内ユーザとして全件参照＋既定マトリクス。`basic-design.md` §3-1）。

## R2: CRM中核

- 2026-08-15 CTO決定（03§8-2）: 決定Dの通り`Customer`で進める（現行JasminCustomerは既にAuthenticatable+customerガードでマイページログインを兼ねており、決定Dは実態と矛盾しないため）。T-4は設計負債として記録しR2完了後にCEOへ再分割要否を提案する
- Customer（拡張37カラム込みの完全版スキーマ）/ Store / Order（約90フィールド・Column.md準拠）
- OrderWorkDetail（SNS認証情報は ActiveRecord::Encryption）
- Product / Plan / ProductInitialFee / ProductOption / 販売許可
- OptionGroup / OptionValue（closure_tree等でツリー）/ CustomerStatus / OrderStatus
- 自動採番の安全化（採番テーブル＋ロック）
- ProductionCompany / SalesMaterial
- 検索・ページネーション（pagy）・CSV非同期エクスポート基盤
- **R1で確立したPundit policy_scope（代理店=自代理店のみ・グループ=配下のみ）をCustomer/Store/Orderにも適用**（2026-08-15追記: 「以降の全エンティティで必須」の原則がR2本文に明記されていなかったため。R2完了条件に含める）
- 自動採番（count()+1脆弱性の是正）の並行処理挙動をrequest specでカバーする（2026-08-15追記: T-1負債対策がR3以外に広がっていなかったため）

**R2完了条件（2026-08-15追記）**: 案件90フィールド・ステータス管理に加え、代理店ユーザで他代理店のCustomer/Order一覧・詳細・更新に到達できないことをrequest specで確認。

**R2見直しレビュー残タスク（2026-08-17追記）**: ログの機密情報フィルタ漏れ（`filter_parameter_logging.rb`が`*_pass`系カラムにマッチしない）・OptionValueの循環参照/グループ越境防止バリデーション欠如・CSVエクスポートのOrderスコープテスト不足・採番並行処理のrequest spec不足・Order`customer_id`/`store_id`付け替えによるデータ整合性リスクは発見・是正済み（commit `50bd98d`）。加えて以下は機能追加に近く見送り:
- **販売許可の管理UI未実装**: `AgencyProduct`/`AgencyGroupProduct`（Product×Agency/AgencyGroup中間テーブル）はモデル・クエリ（`Product.sellable_by`）のみ実装済みで、staffが管理画面から代理店/代理店グループへ商材の許可を付与・剥奪する手段が無い（現状はコンソール/直接DB操作でしかレコードを作れない）。旧Laravelには`AgencyController#products`等のUIが存在したため後退。`admin/agencies_controller.rb`・`admin/agency_groups_controller.rb`（またはProduct側）に`product_ids`同期アクションの追加を推奨。
- Store一覧に検索・ページネーション（pagy）が無い（他のCustomer/Order/マスタ一覧は全て対応済みでStoreのみ未対応）。
- Store向けCSV非同期エクスポートが未実装（`CsvExportJob::EXPORT_TARGETS`にCustomer/Orderのみでstoreが無い）。
- PII方針（Q-D）: OrderWorkDetail/billing_password等（分類B）の暗号化は実装済みだが、Customer本体のPII（氏名・電話・メール等、分類A）を暗号化しない方針自体が`pii-handling-rules.md`/本文書に正式決定として明記されていない（実装が先行し決定記録が後追いになっている）。運用開始前に決定を文書化することを推奨。**→ 2026-08-19 v4: Q-D を Q-D-1〜3 に分割（下記）**。

**R2 追加タスク（2026-08-19 設計ドキュメント精査で判明）**:
- **【要対応】ステータス呼称（Q-B）の実装が中途半端な状態で放置されている**（出典: `status-naming-analysis.md`）。同書の推奨案A（DB変更なしで表示用語のみ「案件ステータス」「申込ステータス」「契約ステータス」の3語に統一）に対し、実装は`order_statuses`側のみ「案件ステータス」表記へ統一済みで、`customer_statuses`側は`app/views/admin/customer_statuses/index.html.erb`等で依然「顧客ステータス」のまま。決定D（モデル名の`jasmin_`除去）とは別問題である点に注意。
  - **2026-08-19 v4訂正**: 案Aは `development-plan.md` §8 の **D-8（2026-07-26 CEO承認）で決定済み**であり、未決ではなく「決定の適用漏れ」。本書に決定として記録する: **Q-B = 案A採用（D-8）。表示用語は「案件ステータス（order_statuses）」「申込ステータス（customer_statuses）」「契約ステータス（R5契約ワークフロー）」の3語**。テーブルリネーム（Phase 2）は行わない（`ApplicationStatus` 命名が既存 `Application` モデルと衝突するため）。
  - 対応（R5着手前・CTO判断で実施可）: `status-naming-analysis.md` §4-1/4-1b の修正ファイル一覧に従い、`app/views/admin/customer_statuses/{index,new,edit}.html.erb` の h1、`admin/customers/{_form,show,index}.html.erb` のラベルを「申込ステータス」へ、`admin/orders/{_form,show,index}.html.erb`・`mypage/dashboard/index.html.erb` のラベルを「案件ステータス」へ統一。`Column.md` §9/§10 の呼称も同時に揃える。
- 未収情報フィールド（売上伝票番号・未回収額等）の追加要否（出典: 旧`remaining-tasks.md`7-1。同ファイルは2026-08-19に削除済みだが本項目のみ拾い上げ）。現行schemaに該当カラムが見当たらず本文書にも未記載。R2追加カラムとするかR6（集計・請求まわり）で扱うかを含めて要否から判断すること。

**R2 追加タスク（2026-08-19 v4追記・Column.md/schema.rb 突合で判明。出典: `Column.md` §4/§7/§8/§14、`legacy-research/12`）**:
- `plans.contract_unit` / `initial_construction`（旧 契約単位(168)/初期構築(169)）は Column.md に設計済みだが schema 未反映（Q-移18）。R2追補で列追加するか R5契約フローで扱うかを要否から判断。
- `customers.email` unique index の業務妥当性確認（同一メールで複数契約者を登録する業務があるか。NG なら認証キーを別列に）。R7 の重複メール顧客投入にも影響。
- `sales_representatives.sales_rep_code`/`name`/`pdf_*` の長さ制限（旧 VARCHAR(50)/(100)）を model validation で追加するか（低）。`agency_groups.service_type` インデックス要否（低）。
- 新規採番形式（`customer_number`=`C-%06d`、`order_number`=`ORD{YYYY}{%04d}`）の業務確定と、旧 FTW/JET・BP/BR prefix との共存方針・R7 移行データとの非衝突確認（DM-8）。
- **PII 方針（Q-D）を3論点に分割して決定を記録する**（出典: `pii-handling-rules.md` §5-2）:
  - Q-D-1: 分類B（SNS認証情報）を新システムへ運ぶか（運ぶ場合は `encrypts` 列へモデル経由 load）— **R7着手前**に決定
  - Q-D-2: 分類A（Customer/Store 本体PII）の暗号化 — A-1 現状追認（平文＋アクセス制御＋at-rest暗号化。**推奨**）／A-2 選択的暗号化／A-3 全面暗号化（pg_bigm 検索と矛盾）— **R8前**に決定
  - Q-D-3: 分類C（`netmove_member_id` 等）— C-1 deterministic `encrypts`（**推奨**。R5前なら手戻り無し）／C-2 平文 — **R5着手前**に決定
- 「Column.md は schema.rb に追従」の運用ルール化（マイグレーション追加時に Column.md 更新を PR チェック項目に）。R5/R6 で新テーブルを追加した際は Column.md §13 → 本文へ昇格させることを各フェーズ完了条件に含める。

## R3: 申込フォーム（受注入力）

- 営業担当者の独自セッション認証（代理店CD＋営業CD）
- FormTemplate / FormStep / FormField — **P2拡張後仕様**（target_table / target_column / editable_by_tier / lock_after_status）を初期実装
- 動的マルチステップ + 動的バリデーション生成
- 申込完了トランザクション（Customer + Store + Order + Application 一括生成）+ メール/スタッフ通知
- フォームビルダーUI
- **申込トランザクションの request spec 必須**（Laravel側の未カバー教訓）

**R3見直しレビュー残タスク（2026-08-17追記）**: FormField#target_columnにホワイトリストが無く、フォームビルダー操作者がagency_id等の内部管理カラムやOrderWorkDetailのSNS認証情報カラム・Order/Customerの業務ステータス列(status)へ直接マッピングできてしまう脆弱性（重大）、FormTemplate削除が進行中Applicationを巻き込んで500エラーになるバグ、申込完了後もApplication#form_dataに機密情報が平文で残り続ける問題は発見・是正済み（commit `7cb7dc4`, `06d8693`）。加えて以下は見送り:
- 営業担当者ログイン成功時に`session.regenerate_id`（またはreset_session）を呼んでおらず、Devise(Users)フローとの防御に非対称がある（session fixation対策。cookie store環境下での実害は限定的だが一般的な防御原則から逸脱）。
- form/admin共通でセッション絶対有効期限（`expire_after`）が未設定。特にform配下は社外の代理店担当者が使うため優先度を検討したい。
- `config.force_ssl = true`（本番環境のHTTPS強制・secure cookie）が`config/environments/production.rb`でコメントアウトのまま。
- 申込フォーム画面にログアウト導線（`Form::SessionsController#destroy`へのリンク）がUIに存在するか未確認。
- `OrderWorkDetail`専用のPundit Policyが存在しない（現状admin側に編集UI/ルートが無いため実害なしだが、将来UIを追加する際は親Orderの代理店スコープを継承する形で新設が必須）。
- 中間無効化（ログイン中に`is_active: false`にされた営業担当者が次アクセスで強制ログアウトされる）挙動を検証するrequest specが無い（実装ロジック自体は妥当と判断）。
- **→ 2026-08-19 v4: 上記のセッション/Cookie ハードニング3件（reset_session・expire_after・force_ssl）は R8「本番前必須」（release-readiness.md C-13）へ格上げ**。

**R3 要確認（2026-08-19 設計ドキュメント精査）**: `form-template-mapping.md`のうち、フレームワーク部分（target_table/target_column/editable_by_tier等の動的マッピング機構）は03§5・R3で実装済みだが、同書§2が列挙するBRIDGE_PLUS向け個別フィールドとR3実装済みFormField定義との突合は未実施。
- **2026-08-19 v4 突合結果**（`form-template-mapping.md` §9 実装突合表）: 「155項目」は概数で、§2 の field_key 実数は **67件**（2-1: 12 / 2-2: 43 / 2-3: 12）。**67件全件が未投入**（BRIDGE_PLUS 用 FormTemplate/FormStep/FormField は seed・factory・開発DB のいずれにも存在しない）。ただし保存先カラムは全て R2 スキーマに実在（列名差異1件: `name_kana`→`contractor_name_kana`。要マイグレーション0件）。型読替が要るもの: yes_no系14件（保存先 string(5) のため `field_type: boolean` だと `"t"/"f"` が入る→select＋文字列表記を要決定）、tel/email 6件（形式検証なし）、number 5件、date 1件、select 8件（インライン choices）。

**R3 残タスク（2026-08-19 v4追記。出典: `form-template-mapping.md` §4/§6/§7/§9、`business-flow-analysis.md` G-4）**:
- **【高・セキュリティ】`FormField.allowed_target_columns_for("customer")` が Devise/OTP 認証列（`encrypted_password` `otp_code_digest` `otp_code_expires_at` `otp_attempts` `unlock_token` `locked_at` `failed_attempts`）と `netmove_member_id` を許可している** → 除外リスト追加＋spec（CTO判断で即実施可）。
- **【高】BRIDGE_PLUS 初期テンプレート67フィールドの投入手段決定と投入**（(a) ビルダー手入力 / (b) seed・rake / (c) インポート機能）＋ OptionGroup シーダー（prefecture / payment_method / yes_no / applicant_type / 属性1〜11 等。開発DB 0件）の併設。**R5 の申込→決済導線が動く前提条件**のため R5着手前に完了させる。
- 【中】§4 契約後スタッフ入力カラムをホワイトリストから機構的に除外するか（業務判断）。
- 【中】`validation_rules` に format 検証（email/tel/postal_code）を追加（`customers.email` はマイページのログインID）。
- 【中】yes_no 系 string(5) 列の保存値表記の決定（R7 移行元表記と整合）。
- 【低】`input_options.option_group_key`→OptionGroup 参照解決、WorkDetail 個別フィールドのフォーム組み込み範囲（R6）。
- **2026-08-19 v5 CEO決定**: 顧客本人が入力する導線は**ハイブリッド方式**を採用（営業担当者が入力して仮申込を作成→顧客にメールでリンク送付→顧客がそのリンクから申込を再開）。`Application#token` 付き URL の別セッション許可＋有効期限管理をR5で実装。詳細はR5節「R5-6」付近の実装タスクに追加すること。

## R4: 問い合わせ・通知

- Inquiry / InquiryMessage / 添付 / 宛先解決（RecipientResolver移植）
- **掲示板4種→問い合わせ統合（決定D-11・board-implementation-options.md）**: Inquiryモデルの種別別ステータスマスタ化・enum撤廃・種別×ステータス→宛先ルーティング・アフター固有列追加（2026-08-15追記: 過去データのアーカイブ投入＝R7とは別に、Inquiry拡張本体がR4に漏れていたため）。**2026-08-19 v4: 4項目とも実装済みを確認**（アフター固有列は列のみでフォームUI未。`board-implementation-options.md` §0）
- 一斉通知（フィルタ・スケジュール送信・テンプレート・宛先グループ）
- アプリ内通知（SystemNotification + Solid Cable リアルタイム + 30日prune）
- 顧客マイページ（ログイン+ダッシュボード。Laravel現行と同等の最小構成から）

**R4 未実装ギャップ（2026-08-19 設計ドキュメント精査で判明）**:
- **問い合わせ返信テンプレート機能が未実装**（出典: `legacy-research/13-faq-templates.md`）。R4実装の`NotificationTemplate`は`template_type: inquiry`という区分を持つのみで、同書が前提とする「FAQ 12カテゴリのマスタ」「差し込み変数の展開」「問い合わせ返信画面でのテンプレ選択UI（`inquiry_messages_controller`から未参照）」は存在しない。矛盾ではなく機能ギャップ。
  - **2026-08-19 v5 CEO決定: 実装する。R6（運用強化フェーズ）で着手**。投入対象の実データ（FAQ 318件）はR7のデータ投入と合わせて実施。
  - 2026-08-19 v4補足: 一斉通知側の「テンプレ選択→本文コピー」機構が流用可能。未実装は (1) カテゴリ/タグ列 (2) 差し込み変数 (3) 返信画面の選択UI (4) 318件 seed の4点。
- **通知マトリクスの未決事項が答え合わせされないまま実装が先行した形跡**（出典: `notification-matrix.md`）。通知の仕組み（`RecipientResolver`/`NotificationTemplate`/`RecipientGroup`/`SystemNotification`/`InquiryRecipientRoute`）はR4で実装済みだが、同書のE1〜E12のうちE1/E3/E6/E7/E8/E12等は「?要確認」のままで、実装時にどう確定させたかの記録が本文書に無い。
  - **2026-08-19 v4: `notification-matrix.md` に「実装済みルール」列を追加し記録無し状態は解消**。確定状況: E1（申込受付→実務運用者ロール全員）・E2（申込確認→顧客のみ・Ccなし・添付なし）・E4/E9/E10（案件の代理店/営業/顧客＋ルート宛先）・E13（一斉通知）= 実装済み／E3・E5・E6 = R5／E7・E8 = R6／E11・E12 = R6 未実装。
  - E6（決済失敗の通知先）はR5、E8（自動キャンセル時に顧客へ通知するか）はR6の遅延検知と連動するため、**R5/R6着手前チェックリストで実装済みルールとの整合を確認**すること。

**R4 追補タスク（2026-08-19 v4追記。出典: `board-implementation-options.md` §0/§5、`notification-matrix.md` §1〜§3、`basic-design.md` §17）**:
- **【高・2026-08-19 v5 CEO決定＝修正する】`RecipientResolver#recipients_for_inquiry` の合成規則**: 現行は全投稿で案件の代理店（email_1〜5）・営業担当者・顧客のメール保持者を必ず宛先に含め、`is_visible_to_agent=false` でも代理店へメールが飛ぶ（旧設計 05§5-1 は販売店宛をステータス限定・顧客宛なし）。CEO決定により、`is_visible_to_agent` 等の見える範囲・ステータスに応じて宛先を絞るよう修正する。
- 【高】`RecipientGroup`／`InquiryRecipientRoute` の初期投入（旧設計 05§5-1 マトリクス・転送先13件相当。シード or 運用手順書）。外部委託先アドレスの User/ProductionCompany 化方針を含む（`RecipientGroupMember` は User/ProductionCompany のみ・UI は User のみ）。
- 【中】一斉通知フォームにフィルタ入力UI（ラベル「申込ステータス」）を配置（`filter_params` は実装済み・UI未）。件名形式（C4）統一要否→`InquiryMailer`/`NotificationMailer` 修正。
- 【中】アフター固有列のフォーム配置・選択肢固定値化、次回対応者ベースのルーティング（05§5-2）の要否。Inquiry 本文 2,000 文字上限の要否。
- 【低】`inquiry_statuses`/`inquiry_recipient_routes` CRUD の request spec。添付 MIME 制限。
- 未実装（R6送り）: 通知一覧・既読UI（論点15「通知一覧UI無しで運用開始してよいか」）、C1/C2 通知設定、C6 通知しないオプション、顧客側公開問い合わせフォーム・メールリンクからの顧客返信（`basic-design.md` §17-1）。

## R5: 契約フロー・決済（Laravel未実装 → 新規設計実装）

- PaymentTransaction 状態機械の忠実移植（unknown≠failed / mark・confirm分離 / 二重送信防止）+ 決済監査ログ
- **決済専用キュー＋自動リトライ無効化**（payment-integration.md §4-2: デフォルト再試行のまま流すと二重課金を自動で起こす。2026-08-15追記）
  - 2026-08-19 v4具体化: `config/queue.yml` に `payments` ワーカー（threads 1）を分離、`queue_as :payments`、`retry_on` 禁止（`discard_on ActiveJob::DeserializationError` のみ）、`limits_concurrency`（jutyu_cd キー）、`lock_version`
- ネットムーブ連携（payment-integration.md 準拠: リダイレクト型・HMAC-SHA256・非保持非通過・突合）
  - 2026-08-19 v4: HMAC は `OpenSSL::HMAC` + `ActiveSupport::SecurityUtils.secure_compare`（`Payment::CheckCode`）、鍵はサイトコード単位で credentials/ENV → `Payment::Config`
  - **ret_url/cancel_url 受け口は form section（`Form::PaymentReturnsController`）に置く**（CTO決定候補・03§8-2 と同様の自律決定枠）: `form/` は RBAC 完全スキップ済み（決定b）で `SystemPermissionSyncService` を改修せずに済み、`skip_forgery_protection`＋認証スキップが1コントローラに閉じる。セッション不参照で `PaymentTransaction` を復元。Webhook 提供時の `webhooks/` 名前空間新設は再検討（`payment-integration.md` §4-10）
  - **決済通信ログは `payment_transaction_logs` を AuditLog と別に持つ**（`audit_logs.user_id NOT NULL` のため ret_url 等ログインユーザ無しの記録を載せられない。管理者操作は `Auditable`/`AuditLog`）（`payment-integration.md` §4-5）
- 契約ワークフロー状態機械（不備チェック→差戻し→確認コール→契約確定）
  - 2026-08-19 v4具体化（`basic-design.md` §9〜§12）: §9〜§12 のステータスを Q-B 案A「契約ステータス」1本に統合した手実装状態機械（`orders.contract_status` 拡張 or `contract_workflow_states` マスタ）+ `contract_reviews`（遷移履歴・差戻し理由/対象項目/コメント/差戻し先）。決済状態→業務ステータス連動は `Payment::OrderStatusSyncService`
- 契約書PDF生成・版数管理・メール送付、手書き署名
  - 2026-08-19 v4具体化: `ContractDocument`／`OrderDocument`（order_id / version / document_type / snapshot / is_latest）+ Active Storage + PDF gem 選定（grover/ferrum vs prawn。**R8 の Docker/デプロイ構成＝Chromium 同梱可否と連動**）+ `Documents::PdfRenderer` + `OrderDocumentGenerateJob` + `ContractMailer`/`OrderDocumentMailer`。手書き署名は Active Storage 添付。**`applications.form_data` は完了時にクリアされるため、確認書スナップショットは生成時に Customer/Store/Order から組み立てて固定する**（`contract-confirmation-docs.md` §3-2）
- 入力チェック設定（3段階必須）・**キーワード自動選定（P3-11。2026-08-15追記: 01§5未実装一覧にあったが計画から脱落していたため復元）**・重説チェック・申込確認メール
  - 実装順の知見（contract-confirmation-docs.md）: 重説チェックは契約ワークフロー状態機械（P3-4）より先に単独実装すると「重説未実施の案件を不備チェックへ進めてよいか」が状態機械側の論点になり手戻る。**状態機械の設計を先に固めてから重説チェックへ着手する**
  - 2026-08-19 v4具体化: 入力チェック設定 = `InputCheckRule` + `InputCheckRuleEvaluator`（申込フォームと管理画面編集の共通呼び出し。「3段階必須」を `FormField.requirement_level` か `InputCheckRule.severity` のどちらで持つか着手時に決定。G-3）。キーワード自動選定 = `KeywordSuggestionService` + Stimulus（保存先は既存 `order_work_details.keyword_industry_main/sub1〜4`）。重説チェック = `disclosure_item_sets`/`disclosure_items`/`disclosure_checks`/`disclosure_check_items`（実施 section は Q-2 次第）
- **決済状態機械（PaymentTransaction）のrequest spec必須**（2026-08-15追記: payment-integration.md §6「省略しない。タイムアウト・二重送信・改ざんは手動再現不可」の要求が完了条件に反映されていなかったため）
- **ネットムーブ会員ID（カード情報）の引き継ぎ対応**（2026-08-19追記。出典: `netmove-card-migration.md`）: CEO判断は「カード情報は会員IDで引き継がれる前提」。カラム自体はR2で`customers.netmove_member_id`/`netmove_registered_at`として実装済みだが、以下がR5本文から漏れていた。
  - 会員ID採番が新旧で連続すること（既存顧客の会員IDと衝突しない採番設計）→ `Payment::MemberIdAllocator`（既存優先/`SequenceCounter` 採番。形式「6＋7桁連番」仮説は回答待ちのため固定しない）
  - カード変更導線（ネットムーブ `member-modify`）の実装 → section（mypage で顧客本人 / admin からメールリンク案内）未決。S-7 回答後に実装（R5 ではスコープ境界の明記のみ）
  - 旧CRM顧客管理エクスポートの「ネットムーブ会員ID」列を取り込むETL枠（R7と連携。`lib/tasks/etl/netmove_member_ids.rake`）
  - 2026-08-19 v4追加: `customers.netmove_member_id` の部分ユニークインデックス、`Auditable TRACKED_FIELDS["Customer"]` へ `netmove_member_id`/`netmove_registered_at` 追加（現行は会員IDの変更履歴が監査ログに残らない）
- **請求用受注データCSV出力の実装先を確定する**（2026-08-19追記。出典: `payment-integration.md` D-P8）: 「継続課金の売上処理はTBSSスコープ外。新システムは請求用受注データのCSV出力のみを担う」という決定がR5本文にもR6のCSV汎用化にも明記されていなかった。
  - **2026-08-19 v4 確定案: R5 で `CsvExportJob::EXPORT_TARGETS` に `BillingOrder` プロファイルを1エントリ先行追加（staff 限定・列は TBSS ヒアリング後・spec 先行）→ R6 の P4-12 汎用化（`export-profile-design.md` §4 Step 9）で YAML プロファイルへ移設**。締切＝カットオーバー後最初の月次請求（25日前後）
- 2026-08-19 v4追記（`payment-integration.md` §2-2/§4-7、`business-flow-analysis.md` §7-2）: 決済ステップは R3 の `Form::ApplicationSubmissionService`（Customer/Store/Order 一括生成）の **Order 作成後に差し込む**。3DS 項目の転用元（`customers.email`/`sms_mobile_number`/`mobile_phone`/`prefecture`）は `Payment::CardholderInfoBuilder`。D-P12① フォームでの支払方法3択分岐（おまとめ時スキップ）は R5。`contract_conditions` に最低利用期間・更新周期・違約金を持たせるかは R5 で要確認。伝票番号（発送用/返送用）カラム要否（`legacy-research/05` §2-1）も同時判断。
- 2026-08-19 v4追記（`customer-merge-design.md` §6-2）: **R5 で顧客 FK を持つ新テーブルを追加した場合は、R6 名寄せの `CustomerMergeService` 移管対象に追加する**ことをスキーマ設計チェック項目とする。

**R5 実装タスク分解案（2026-08-19 v4追記。出典: `review/review-06` サマリC・A・F。順序=依存順）**:

| 順 | タスク | 主な出典 | 優先度 |
|---|---|---|---|
| R5-0 | 着手前チェックリスト確定（下表）＋ ret_url の section 配置・カード変更導線の section を CTO 判断で確定 | payment §8/§4-10 | ブロッカー |
| R5-1 | **契約ワークフロー状態機械（P3-4）の設計確定** — `orders.status`/`contract_status` の遷移表、決済未完了 Order の扱い、重説完了を遷移条件にするか（Q-4）、案件初期ステータス（`0:受注` の扱い。DM-6） | basic-design §9〜12、contract-confirmation §4 | 高（他タスクの前提） |
| R5-2 | migration: `payment_transactions`/`payment_transaction_logs`（payment §5）、`netmove_member_id` 部分ユニークIDX、`Auditable TRACKED_FIELDS` 追加、Column.md §13→本文昇格 | payment §5、netmove §6 | 高 |
| R5-3 | `PaymentTransaction` 状態機械（遷移表・mark/confirm・`with_lock`・`lock_version`）+ model spec | payment §4-4 | 高 |
| R5-4 | `app/services/payment/`: Config / CheckCode / JutyuCodeGenerator / MemberIdAllocator / CardholderInfoBuilder / ParamMasker + unit spec | payment §4-9/§4-10 | 高 |
| R5-5 | Solid Queue 決済専用キュー（`queue.yml`・`retry_on` 禁止・`limits_concurrency`）+ job spec | payment §4-2 | 高 |
| R5-6 | 決済開始 `Form::PaymentsController` + `Payment::CheckoutSession` + D-P12① 3択分岐 + 3DS 項目送信 | payment §4-10/§4-7 | 高 |
| R5-6b | **【v5 CEO決定】顧客本人入力導線（ハイブリッド方式）**: 営業担当者が仮申込を作成→顧客へメール送信→`Application#token` 付きURLで顧客が別セッションから申込を再開・決済まで完了。トークン有効期限・再送・なりすまし対策のrequest spec必須 | basic-design §6、04次のアクション6 | 高 |
| R5-7 | ret_url/cancel_url 受け口 `Form::PaymentReturnsController` + `Payment::ReturnHandler` + rack-attack + **request spec（Cookie無し/改ざん/二重POST）** | payment §4-9/§4-10、R-12 | 高 |
| R5-8 | `Payment::OrderStatusSyncService`（決済→業務ステータス連動） | payment §4-6 | 中 |
| R5-9 | 管理画面 `Admin::PaymentTransactionsController`（一覧/詳細/手動再開/突合確定）+ `PaymentTransactionPolicy`（親 Order の代理店スコープ継承）+ `Admin::PaymentReconciliationsController` + `Payment::ReconciliationJob` | payment §4-3/§4-10 | 中 |
| R5-10 | 請求用受注データCSV: `EXPORT_TARGETS` に `BillingOrder` 追加 | payment §4-8、export-profile §7 | 中（締切あり） |
| R5-11 | PDF 生成基盤選定 + `Documents::PdfRenderer` + `OrderDocument`/`OrderDocumentDelivery` migration + `OrderDocumentGenerateJob` | contract-confirmation §3-2 | 中 |
| R5-12 | 申込確認メール（P3-13）: `OrderDocumentMailer` + `NotificationTemplate` 値追加 + E2 宛先（`RecipientResolver`）+ source_snapshot | contract-confirmation §3-2 Q-7 | 中 |
| R5-13 | 重説チェック（P3-12）: `Disclosure*` 4テーブル + 実施UI + 管理画面版管理 + Policy | contract-confirmation §3-1 | 中（R5-1 の後） |
| R5-14 | 入力チェック設定（`InputCheckRule`）・キーワード自動選定（`KeywordSuggestionService`）・契約書PDF・版数管理・契約確認メール・手書き署名（R5-11 の器を共用） | basic-design §8/§11/§13/§14 | 中 |
| R5-15 | 実結線確認（P3-2-i）は Q-39 確定後（商用カード・1円与信＋与信取消）。`legacy-research/15` のテスト購入結果は未記入＝Q-37/38 の一次確認未了 | payment §6/R-6 | — |
| R5-16 | カード変更導線（member-modify）はスコープ境界の明記のみ（S-7 回答後に実装） | netmove §3/§6-4 | 低 |

**R5着手前チェックリスト（2026-08-15追記 / 2026-08-19拡充 / 2026-08-19 v4 再拡充 / 2026-08-19 v5 CEO決定反映）**: `development-plan.md`§8で未確認のまま残っている論点のうち、**CEO判断が必要だった8論点は v5 で全件決定した**。残る Q-35〜39（重説チェック詳細・決済技術仕様・ネットムーブ回答待ち）と、CTO判断で着手可能な項目のみ引き続き未着手。

### 決定済み（2026-08-19 v5・CEO回答）

| 論点 | 内容 | 決定 |
|---|---|---|
| Q-25 | 返金・キャンセルの業務要件 | **状態記録のみ**。実際の返金処理（与信取消等）はシステム外・手作業/決済代行会社の管理画面で対応。実装は状態と履歴の記録に限定 |
| Q-26 | 信販をフローに含めるか | **含めない**。支払方法の選択肢は既存（クレジット・口座振替等）のみ |
| Q-27 | 決済障害時の縮退運用 | **一時保留して手動対応**。自動リトライは実装しない（既定の「自動リトライ無効化」方針と整合） |
| Q-D-3 | 分類C PII（`netmove_member_id` 等）の暗号化方針 | **平文のまま**。アクセス制御・監査ログ（`Auditable`）で保護し、暗号化は実施しない |
| G-1/G-9 | 商材別の納品日・作業完了日 | **現状維持**（1案件=1納品日のまま）。スキーマ変更は行わない。旧Q-F/D-4（2026-07-26「別テーブル化」）と矛盾していたため2026-08-19に再確認し、現状維持が最終決定（development-plan.md Q-F 更新済み） |
| DM-6 | 案件初期ステータス（`orders.status` 既定値「0:受注」） | **現状維持**。「受注」を新システムの正式な初期状態として使い続ける。実装変更・移行作業は不要 |
| E3 | 不備差戻し時の通知先 | **営業担当者・社内実務担当者（スタッフ）**。顧客へは通知しない |
| E5 | 契約確定時の通知先 | **顧客（契約書送付メールと同時）・営業担当者・社内実務担当者** |
| E6 | 決済失敗時の通知先 | **通知不要**。営業担当者と顧客がWeb商談でオンライン中に顧客が画面上でカード情報を入力して決済するため、失敗はその場で画面表示され非同期通知の必要がない |
| R4追補 | `RecipientResolver#recipients_for_inquiry` の合成規則（全投稿を代理店・営業・顧客へ自動送信している現行実装） | **修正する**。`is_visible_to_agent` 等の見える範囲・ステータスに応じて宛先を絞る（R4追補タスク） |
| FAQテンプレ | 問い合わせ返信テンプレート機能（FAQ 318件・12カテゴリ） | **実装する**。R6（運用強化フェーズ）で着手 |
| 顧客本人入力導線 | 申込入力を顧客本人の端末からも行えるようにするか | **ハイブリッド方式を採用**: 営業担当者が入力して仮申込を作成→顧客にメールでリンク送付→顧客がそのリンクから申込を再開する。R5で実装（`Application#token` 付きURLの別セッション許可＋有効期限管理が必要） |

### 未決（引き続き保留・次に確認が必要）

| 論点 | 内容 | 出典 |
|---|---|---|
| Q-35 | 重説チェック・確認書の未決事項（項目/実施者/タイミング/宛先/版管理）= `contract-confirmation-docs.md` Q-1〜9（Q-7 は開発判断で可・推奨(b)専用Mailer） | development-plan.md §8 / contract-confirmation-docs.md |
| Q-36 | 決済トランザクションの紐づけ単位（`payment-integration.md` §8 論点9 の結論=`customer_id` 主・`order_id` 併記で閉じてよいか） | development-plan.md §8 |
| Q-37 | jutyu_cd（受注コード）の桁数問題 | development-plan.md §8 / legacy-research/02-payment-netmove.md |
| Q-38 | 決済結果の確定手段（ret_urlに結果コードが無い問題） | development-plan.md §8 / legacy-research/02-payment-netmove.md |
| Q-39 | ステージング検証方式 | development-plan.md §8 |

### CTO判断で着手可能（CEO確認不要・事後報告）

| 論点 | 内容 | 出典 |
|---|---|---|
| **Q-B適用** | D-8 決定済みの呼称統一（`customer_statuses`=申込ステータス）をビューへ適用完了 | status-naming-analysis.md §4-1 |
| **G-10** | 案件ステータス全35値のシード投入（現行 `StatusSeeder` は5値のみ）＋統廃合後コード表・code 安定キー化 | business-flow-analysis.md §3-1/§3-3、status-naming-analysis.md §1-2 |
| **verify系** | `after_action :verify_authorized`/`verify_policy_scope` 導入（R0見送り事項の格上げ） | release-readiness.md F-10 |
| **rack-attack** | form/mypage の OTP・ログイン、`/users/sign_in` へのスロットル拡張 | release-readiness.md C-6 |
| **R3残** | FormField ホワイトリストの認証列除外（セキュリティ）／BRIDGE_PLUS テンプレ67フィールド＋OptionGroup 投入（決済導線の前提） | form-template-mapping.md §9 |
| **section配置** | ret_url 受け口=form section、カード変更導線の section | payment-integration.md §4-10 |

- 2026-08-19追記: Q-35〜39は04に未記載だったため今回追加した。うちQ-25〜27はv5で決定済み。残るQ-35〜39は重説詳細（業務・法務判断）とネットムーブ回答待ちの技術仕様のため、決定次第追記する。
- 併せて`release-readiness.md` D領域（決済・契約の非機能要件。v4で D-8 決済専用キュー・D-9 会員ID引継ぎを追加）もR5着手前に確認する。
- **注意**: `release-readiness.md` A-1「RDSはMySQL 8.4 LTSで構築」はLaravel側限定の決定であり、**03決定A（PostgreSQL）が正**。v4改訂で同書は PostgreSQL 16 / Solid Queue・Cache・Cable 前提に書き換え済み。

## R6: 運用強化（P4群・優先度は都度判断）

- 顧客横断統合ビュー / 項目一括更新 / 顧客名寄せ（customer-merge-design.md）
  - **customer-merge-design.mdが列挙する高リスク並行処理（lockForUpdate・TOCTOU再検証・ワンタイム消費・代理店またぎ検知）はrequest spec必須**（2026-08-15追記: T-1負債対策の範囲にR6が含まれていなかったため）。2026-08-19 v4: 同書 §8 に request spec 必須事項 S-1〜S-8（行ロック/TOCTOU/ワンタイム消費/代理店またぎ検知/ロールバック/退会後ログイン遮断/認可/監査）を明文化。R6 完了条件とする。`remember_token` 不在のため `encrypted_password=""` で全セッション失効させる方式。代理店またぎ統合を許可するか（暫定「許可＋履歴で検知」）は業務判断
- メンション / 通知一覧強化（ftlog本体の実装を一次情報とする。※出典だった`ftlog-port.md`は2026-08-19に削除済み）
- 遅延案件検知・自動キャンセル・集計レポート・外部CSV取込・ガルーン連携 等
- **CustomerStatus/OrderStatusの遷移バリデーション**（2026-08-17 R2見直しレビュー追記）: 現状は`code`がマスタに存在するかのみ検証し、不正な遷移（例: withdrawnからappliedへ戻す等）を防ぐルールが無い。R2時点ではLaravel側・Column.mdにも遷移ルールの明記が無いため許容し、本タスクとして先送り済み。R5の決済状態機械（別物）とは切り分けて設計すること。G-10 投入後に着手
- **CSVエクスポートの複数プロファイル対応・汎用化（P4-12）**（2026-08-19追記。出典: `export-profile-design.md`）: R4で基本のCSV非同期エクスポート基盤は実装済みだが、「エンティティ横断・出力列を利用者が選べる複数プロファイル」への汎用化は未着手で、本文書にもタスクとして存在しなかった。設計思想（config管理 vs DB管理の比較、出力可能列カタログのホワイトリスト化）は移植価値が高い。**2026-08-19 v4: 同書を Rails 版（`config/csv_export_profiles.yml` + `CsvExportProfile` 値オブジェクト + `CsvExport::Catalogs/Sources/Writer`、暗号化列のカタログ除外を spec で禁止、PII 列DLの AuditLog 記録）に書き直し済み**。分解: Step 1〜6 基盤（Q-15 非依存）／Step 7 アシスト納品（Q-15 後）／Step 8 Store／Step 9 請求用CSV移設（R5 完了後）。決定事項: CSV 既定を UTF-8 BOM 付きにするか・成果物保存先（現行 `csv_exports.file_data` text 直保持）・`csv_download_visible` の意味づけ・`expires_at`＋定期削除
- **業務フロー資料の差分G-1〜G-9の反映状況確認**（2026-08-19追記。出典: `business-flow-analysis.md`）→ **2026-08-19 v4: Rails版判定完了**（同書 §9-2）。G-2 = R4対応済み／G-4 = 一部（列と OptionGroup はあり・データ投入と FormField 連携なし。R3残へ）／G-7 = 一部（重複列残存）／~~G-1・G-9~~ = **2026-08-19 v5 CEO決定・現状維持で解決済み**（旧D-4は撤回）／G-10 = R5前ブロッカーのまま（ステータス35値シード投入）／G-3・G-6 = R5／G-5・G-8 = R6。§7 の請求ルールは R5 の請求CSV出力と関連

**R6 追加タスク（2026-08-19 v4追記。出典: `review/review-06` サマリA・D・F・G・H）**:
- **【2026-08-19 v5 CEO決定＝実装する】問い合わせ返信テンプレート機能**（FAQ 12カテゴリマスタ・差し込み変数展開・返信画面でのテンプレ選択UI。出典: `legacy-research/13-faq-templates.md`）。FAQ 318件のデータ投入はR7と合わせて実施。
- 一覧検索強化を一括タスク化: ユーザ一覧（氏名/メール/権限/所属/状態＋pagy）・顧客一覧（代理店/ステータス/期間、既定=退会済み除外）・案件一覧（顧客メールアドレス条件 P4-6。現行は order_number/status のみ）・問い合わせ一覧（category 以外）・Store 一覧（検索・pagy・CSV）。pg_bigm フリー検索も検討（`basic-design.md` §1-2/§4-2/§15-1/§17-2）
- 汎用監査ログ検索画面 `Admin::AuditLogsController`（ユーザ/操作種別/対象/期間・CSV）+ `logout` イベント記録＋form の CD照合失敗記録（P4-16残。`basic-design.md` §16、`release-readiness.md` E-10）
- 顧客側問い合わせ導線（マイページにスレッド表示・返信フォーム、メールリンク→マイページログイン→返信）、マイページ機能拡充（P4-9）、通知一覧・既読UI・C1/C2 通知設定・C6（`notification-matrix.md` 論点15）
- 通知マトリクス R6 分の宛先確定: E7 遅延・E8 自動キャンセル（顧客通知要否）、E11 メンション・E12 一斉通達（候補集合に顧客を含むか）— **R6着手前チェックリスト**
- 顧客利用停止（退会）専用アクションと退会時の orders/stores/マイページ連動ルール（P4-29/Q-34。遷移バリデーションと同時設計）、顧客詳細のタブ分割（Turbo Frame）、「所属部署」要否、Customer 向けパスワード再設定要否
- ユーザ無効化の運用整理（物理削除との役割分離・固定権限・セッション失効。P4-7）、`UserCsvImport` 履歴永続化（R1見送り事項）、販売許可 UI（R2見送り事項）
- CsvExport 生成物の保持期限＋自動削除ジョブ（Solid Queue recurring。`pii-handling-rules.md` §2-2）
- 旧 P4 で 04 未反映だったもの（`development-plan.md` §3 P→R対応表）: P4-11残（お纏め請求・備考・予備欄）、P4-21（連携状況記録＋連携エラー時の自動アウトバウンドメール）、P4-23（GBP アカウント権限管理・受注完了経過管理）、P4-24（対応音声ログ管理。容量・法務要確認）、P4-26（初回運用レクチャー管理）、P4-27（KW 管理。P3-11 とは別）、P4-28（代理店管理画面での資料共有フル版）、P5-13（月次レポート作成・送付。スコープ外判断と連動）
- 店舗メール／管理者メール（「;」区切り複数）の受け皿要否、アフター問合せの「次回対応者→送付先」ルーティング、G-5 フォームビルダー拡張（一括コピー・自動入力）、G-7 重複列（`customers.num_employees` vs `order_work_details.num_employees` 等）の正規化ルール
- 参照制御の横断テスト拡張（通知宛先検索・問い合わせ宛先解決・マイページの代理店スコープ。`release-readiness.md` F-3）

## R7: データ移行（別プロジェクト切り出し予定）

- legacy-research/ の ETL設計・238フィールドマッピングを流用
- 掲示板42万件は参照アーカイブ（Q-C決定済み）
- **R2のスキーマ設計時点からマッピング整合を常時確認する**（移行を後から考えない）
- **掲示板投稿者の名寄せ手順**（2026-08-19追記。出典: `name-matching-process.md`）: 手入力の投稿者名文字列42万件を新UUIDへ突合する手順（抽出→機械マッチング→人手確認→レビュー→版確定の反復ループ、頻度カバレッジ97%の精度目標）が設計済みだが、本文書では「legacy-research/のETL設計を流用」に含意されるのみで名指し参照が無かった。R7の律速要因の一つとして明示する。2026-08-19 v4: 同書を rake（`legacy:extract_posters`/`legacy:match_posters`）/`rails runner`/Solid Queue/PostgreSQL（pg_trgm/pg_bigm 候補）へ書き換え済み。**書き込み先の実態: 投稿者は `inquiry_messages.created_by_id`（users FK）＝staff のみ FK 表現可。ダミー「移行ユーザ」と `legacy_poster_name` 列の追加が R7 要求事項**。B-7 リハーサル初回の約1か月前に第1周開始
- **R2実装済みスキーマとの整合は確認済み（2026-08-19）**: `legacy-research/`全16ファイルを精査し、現行のCustomer/Store/Order/Plan等と**致命的に矛盾する記述は無い**ことを確認した（`review/review-05-*.md`§6、v4 では全ファイルに実装状況列を付与済み）。なお`legacy-research/12-schema-gap.md`が指摘する「customers 38カラム未実装」はP2-4完了により解消済みで、同ファイルは歴史的記録として読むこと。R7設計時に持ち越す既知の未決事項は以下:
  - Q-移7: `agencies`に住所・電話カラムが無い（代理店の住所管理の要否が未決）
  - Q-移15: 月額料金のスナップショット保存の要否（無いと旧プラン価格変更で既存契約の表示額が変わる）
  - Q-移18: 契約単位(168)/初期構築(169)フィールドの対応先が未定 → v4更新: Column.md は `plans.contract_unit`/`initial_construction` に設計済み・schema 未反映（R2追補候補）
  - DM-7: 旧システムの「施工担当者」概念（36件）が新スキーマに存在しない（R1組織領域の要否確認事項）
  - **DM-6（v4追加）**: 旧→新ステータスマッピングと `orders.status` 既定値 `0:受注` の整合（R5着手前チェックリストと同件）
  - **DM-8（v4追加）**: 旧 FTW 顧客番号の保持列が無い（`orders.serial_id`/`bridge_migration_order_number` は案件側のみ）。`customer_number` に旧番号を入れるか新採番か、`sequence_counters` 開始値
  - **Q-移19（v4追加）**: 営業担当者 `email`（受注入力OTP送信先）の補完元・未設定者の運用
  - **Q-移20（v4追加）**: `orders.contract_condition_id` NOT NULL の受け皿（移行用既定条件を代理店ごとに生成するか）
  - `customers.email` UNIQUE（重複メール顧客の投入不可）、NOT NULL 受け皿（`stores.customer_id`/`sales_representatives.agency_id`/`inquiries.order_id`）、`inquiries`/`inquiry_messages` に旧ID列・投稿者 polymorphic 列なし
- **案件238フィールド突合結果（2026-08-19 v4追記。出典: `legacy-research/11` §0・付録A）**: 実装済みカラム対応 **219**（orders 84 / order_work_details 75 / customers 42 / stores 17 / plans 1）＋ FK 参照解決 **9**／未実装 **2**（168/169 = Q-移18）／対応先なし **8**（13/14 アポインター2人目・79 店舗メール・120 担当者生年月日・132-134 用途不明・233 ID）。**移行先未実装は計10件、いずれも新規機能依存なし。R7着手前に要否判断**。旧「59 顧客ステータス」→`orders.status` 対訳と Laravel code→Rails code 読み替え（`status-naming-analysis.md` §5-5）も R7 で確定

**R7 タスク分解案（2026-08-19 v4追記。出典: `review/review-06` サマリH・I）**:
1. **R7-1 移行基盤**: `lib/tasks/legacy.rake`（`DRY_RUN` 環境変数 or Rollback 方式）、`legacy_migration_logs`（旧数値ID→UUID 対応表・`bbs_id` 受け皿）、Solid Queue 専用キュー、`requirements/input/`（gitignore 受け口）、投入時の監査ログ抑止方針、`SequenceCounter` 繰り上げ、暗号化列（`order_work_details` 8列・`orders.billing_password`）は `encrypts` を通すためモデル経由投入（`legacy-research/09` §6、`pii-handling-rules.md` §4-4）
2. **R7-2 マスタ移行**: agency_groups（`service_type`）→ agencies（Q-移7）→ sales_representatives（Q-移8/19・`sales_rep_code` 重複解消）→ 移行用既定 contract_conditions（Q-移20）（`10` §2〜4）
3. **R7-3 顧客・店舗・案件**: 案件CSV（CP932）起点で customers → stores（Q-移9）→ orders/order_work_details。住所分割 Q-移10/17、ステータス変換表（DM-6）、`customers.email` 重複方針、未実装10件の要否、旧番号保持（DM-8）
4. **R7-4 掲示板42万件→Inquiry 参照アーカイブ**: `inquiry_statuses` 変換表・スレッド復元・`order_id` 未解決分の受け皿・`legacy_poster_name` 追加・本番テーブル vs 別アーカイブ（`legacy_bbs_archives`）（`10` §6、`board-implementation-options.md` §6、Q-44）
5. **R7-5 名寄せ表（律速・先行着手）**: `name-matching-process.md`
6. **R7-6 検証・リハーサル**: V-1〜V-7、冪等再実行、B-7（`09` §7）
7. **R7-7 データ投入（非移行）**: OptionGroup 選択肢（属性1〜11 等。旧 P2-5）、掲示板転送先13件→`RecipientGroup`/`InquiryRecipientRoute`、旧プラン40種超（`is_active: false`）、旧ステータス（`order_statuses` 追加分）、`prefecture_id`→文字列変換表、ネットムーブ会員ID ETL（`lib/tasks/etl/netmove_member_ids.rake`）、FAQ 318件（要否確定後）
   - ※ うち OptionGroup 選択肢と BRIDGE_PLUS フォームテンプレートは R5 導線の前提のため **R3残として先行**（R3 節参照）

## R8: 品質保証・リリース準備（release-readiness.md A〜J）

- 2026-08-19 v4: `release-readiness.md` を Rails 版（PostgreSQL 16 / Solid Queue・Cache・Cable / Puma+Thruster / Kamal or 未定）へ全面改訂し、A〜J 全項目に状態ラベル（✅実装済み／🔶部分実装／⬜未着手／❓要決定+Q番号）を付与。マイルストーン: M1（R0〜R4 達成）／M2（R5）／M3（R8+R7）
- **本番前必須（v4で格上げ）**:
  - セッション/Cookie ハードニング一式: `force_ssl`・`assume_ssl`・`config.hosts`・`expire_after`・form ログイン時 `reset_session`（C-13。R3見送り事項）
  - Ruby バージョン整合（`.ruby-version` 3.3.4 vs 03§2「3.4」。上げるか 03 を訂正。A-14）
  - 本番構成方式（Q-40）・デプロイ方式（Kamal 採否。`config/deploy.yml` の宛先/registry は仮値）・SMTP/`default_url_options`（現状 example.com）・Active Storage 保存先（S3 等）と添付上限（現行 50MB/ファイル・合計制限なし）（A-3/A-8/A-12/A-13）
  - **情シスへのリスク連携（本番構成・DNS/メール・DB/ストレージ・監視・PII・ガルーン）はリードタイムが長いため R5 と並行で着手**（P5-6 / G-2 / W-4）
  - セキュリティ診断（外部脆弱性診断・PCI DSS・PII ゲート・シークレット・アクセス制御）を R8 完了条件に明示（P5-10 / C）
  - `basic-cost.md` 削除に伴う PostgreSQL/Redisレス構成での費用再試算＋構築手順書（A-11）
- その他 R8 タスク: Solid Queue ダッシュボード（`mission_control-jobs`）導入要否・失敗ジョブ運用（A-6/E-7）、CI に `db:migrate`→`db:rollback`→再 `db:migrate` smoke（F-9）、4DB（primary/cache/queue/cable）のバックアップ対象整理・RTO/RPO（Q-41）、監査ログ5年保存の prune 方針、システム利用マニュアルの Web 提供（P5-4/Q-20。顧客まで全対象）、バックヤード作業マニュアル（P5-8）、用語集（案件/申込/契約/問い合わせステータスの読み替え表）、DB/バックアップ at-rest 暗号化の要件化（Q-D-2 A-1 採用の条件）、credentials 流出時の鍵ローテーション手順、Q-A（PII ルール承認・担当者割当）、W-5 リクリックとのカットオーバー当日作業合意（N-1）、リリース時期・段階/一括（Q-1/Q-2）、ドメイン/TLS（Q-42）、ステージングデータ種別（Q-43）

---

## リスク・注意

1. **フェイルクローズの副作用**（新ルート追加→権限付与漏れ→全員拒否）: 起動時sync + 既定マトリクスのコード宣言 + CIガードをR0でセット導入（ftlogの再発事例に学ぶ）。v4注記: `SystemPermissionSyncService#section_for` は form/mypage 以外を admin 扱いするため、決済 Webhook 等で新名前空間を切る場合は RBAC 基盤2箇所の改修が必要（→ ret_url は form section に置く方針）
2. **決済 unknown 状態の扱い**: 実装者が「わかりやすく」failedに丸めないようspecで遷移表を固定
3. **参照制御の全面適用**: R1以降の全エンティティで policy_scope 必須をレビュー観点に（CIのgrepガードで機械検出も検討）。v4注記: `verify_authorized`/`verify_policy_scope` を R5着手前に導入。R6 名寄せでは代理店またぎ統合時に `OrderPolicy::Scope`（orders.agency_id）と `StorePolicy::Scope`（customer.agency_id）で参照非対称が生じる点に注意
4. ~~Laravel側 P2 の進行と並走する場合、**要件の正は requirements/ で一元管理**し二重管理を避ける（どちらのリポジトリを正とするか運用確認）~~ ✅ 2026-08-19 解消。設計ドキュメントをbrige-crm側へ集約し、**以後の正はbrige-crm `requirements/`**と確定。Laravel側は凍結された参照元として扱う。v4: 全設計書を Rails 版へ改訂済み
5. ~~PII/認証情報の暗号化方針（Q-D）はR2着手前に確定が必要~~ → v4改訂: Q-D-1〜3 に分割し、決定期限を Q-D-3=R5前 / Q-D-1=R7前 / Q-D-2=R8前 とする（分類B は実装済み・分類A は現状追認案を推奨）
6. **決定・呼称が実装へ中途半端に適用されるリスク**（2026-08-19追記）: Q-B（ステータス呼称）は推奨案が`order_statuses`側のみに適用され`customer_statuses`側は旧称のまま残った。設計ドキュメント側の「推奨」を実装した際は、**適用範囲を全画面・全モデルに揃えたうえで本文書に決定として記録する**こと（記録が無いと次の担当者が未決と判断できない）。通知マトリクス（R4）でも同種の「未決のまま実装先行」が起きている。v4: Q-B は D-8 決定済みと判明し本書に記録、通知マトリクスは実装済みルールを同書に記録して解消
7. **初期データ未投入のまま次フェーズへ進むリスク**（2026-08-19 v4追記）: BRIDGE_PLUS フォームテンプレート67フィールド・OptionGroup 選択肢・案件ステータス35値・`RecipientGroup`/`InquiryRecipientRoute` ルート・FAQ の初期データがいずれも未投入で、R3/R4 の「機構は実装済み」と「業務で使える」の間に差がある。R5 の申込→決済導線はテンプレ投入が前提のため、**R3残（テンプレ・OptionGroup）と G-10（ステータス）は R5着手前に投入**する。seed/rake で再現可能な形にし、本番投入は R7-7 で扱う
8. **設計書と実装の乖離の再発防止**（2026-08-19 v4追記）: 「Column.md は schema.rb に追従」「新テーブル追加時は Column.md §13→本文へ昇格」「決定は本書に記録」を各フェーズ完了条件に含める。設計書の実装状況ラベル（✅/⚠️/⏳）は実装変更時に更新する

## 次のアクション

1. ~~CEOレビュー: 03の論点A〜F の確定~~ ✅ 2026-08-14 決定済み（03 §8 決定録）
2. ~~確定を反映して 03/04 を v2 に更新~~ ✅ 2026-08-14
3. ~~R0 着手（rails new〜認可移植）~~ ✅ R0〜R4 実装完了（2026-08-18時点）
4. ~~旧Laravel側 requirements/ の設計ドキュメントをbrige-crmへ集約・精査~~ ✅ 2026-08-19（`review/review-05-legacy-design-docs-sweep.md`）
5. ~~集約した設計ドキュメントを Rails 版へ全面改訂し、突合結果を本書へ反映~~ ✅ 2026-08-19（`review/review-06-rails-revision-sweep.md`、本書 v4）
6. ~~R5着手前チェックリストのCEO確認事項8論点を確定~~ ✅ 2026-08-19（v5）全論点決定済み（DM-6=現状維持／RecipientResolver=修正する／Q-D-3=平文のまま／G-1・G-9=現状維持（旧D-4を上書き・再確認済み）／Q-25=状態記録のみ／Q-26=対象外／Q-27=一時保留して手動対応／E3・E5・E6=通知先確定／FAQテンプレ=R6で実装／顧客本人入力導線=ハイブリッド方式。詳細は上記「R5着手前チェックリスト」参照）
7. **CTO判断で即着手可（CEO確認不要・事後報告）**:
   - R3残: `FormField` ホワイトリストから認証列・`netmove_member_id` を除外（セキュリティ）
   - R0追加: rack-attack スロットルを form/mypage/`/users/sign_in` へ拡張、`verify_authorized`/`verify_policy_scope` 導入
   - R2追加: Q-B（D-8）適用 — `customer_statuses` 側ビューを「申込ステータス」、案件側を「案件ステータス」へ統一
   - G-10: 案件ステータス35値のシード（統廃合後コード表は `status-naming-analysis.md` §3-3）
   - R3残: BRIDGE_PLUS テンプレ67フィールド＋OptionGroup の seed/rake 投入（投入手段は (b) seed・rake を推奨）
   - R4追補: `RecipientResolver#recipients_for_inquiry` の宛先絞り込み修正（v5決定）
8. **残るCEO確認事項（R5着手のブロッカー・v5未回答分）**:
   - R5着手前チェックリストのQ-35〜39（重説チェック詳細・決済トランザクション技術仕様。Q-37〜39はネットムーブ回答待ち）
   - Q-D-2（分類A本体PIIの暗号化。推奨 A-1 現状追認）・Q-D-1（分類B＝SNS認証情報を新システムへ運ぶか）の方向性（Q-D-3は決定済み）
9. **CEO確認事項（R5と並行で早期に）**: 本番構成・デプロイ方式（Q-40・Kamal採否）・ドメイン/TLS（Q-42）・SMTP・情シス連携（W-4/G-2）、W-5 リクリックとのカットオーバー合意、リリース時期（Q-1/Q-2）
10. **CEO確認事項（R6/R7着手前）**: E7/E8/E11/E12 の宛先、代理店またぎ名寄せの可否、Q-15 アシスト納品フォーマット、Q-移7/15/18/19/20・DM-7/DM-8、238フィールド中の移行先無し10件の要否、名寄せ精度目標97%と業務側レビュー窓口・SLA、Q-30（受注入力にパスワード再設定を持たせない現実装で確定するか）、Q-9 の業務側（「グループ兼代理店」を単一所属で表現してよいか）、P5-13 月次レポート・P4-24 音声ログのスコープ可否
11. 上記7を実施し、Q-35〜39（重説・決済技術仕様）が確定次第 **R5 着手（契約フロー・決済。R5-1 状態機械設計から）**
