# brige-crm 実装計画（v2）

- 前提: 03-rails-architecture-proposal.md の構成（**論点A〜F はCEO決定済み 2026-08-14**: PostgreSQL / Hotwire+ERB / section3区分 / prefix除去 / rails new+選択移植 / 移行別フェーズ）
- 方針: Laravel の P0〜P4 フェーズ構成を踏襲しつつ、**認可・参照制御・監査を最初のフェーズに前倒し**する
  （Laravel側で「後付けは手戻り大」と分析された箇所を先に固める）
- 状態: v2（構成確定反映）。次アクション=R0着手
- **2026-08-15 CTO洗い直し反映**: 01/02/03との突合レビュー（`review/review-01〜04-*.md`）を受け、網羅性の漏れ（P3-11・掲示板Inquiry拡張・IP許可リスト）とR8新設を本文に反映。決定D（Customer命名）衝突・Q-23（全画面2FA）・formセクションのRBAC統合方式は、CEO不在のためCTO自律決定（03§8-2参照）で解消しR0〜R4着手。誤りがあれば事後にCEO確認・訂正する。

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
4. 認証: Devise（User）+ ftlog式メールOTP + rack-attack + ログイン履歴（AuditLogの絞り込みビュー。専用テーブルではない） + **IP許可リスト**（P4-17。空リスト=全員OTP必須のフェイルセーフをftlog-port.md D-1から踏襲）
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
- `ApplicationController`に`after_action :verify_authorized`/`verify_policy_scope`（Pundit標準の安全網）を追加する。現状これが無く、R2以降で`policy_scope`/`authorize`の呼び出し漏れを機械的に検出できていない（項目10「CIの認可スキップ検出grep」も文字列マッチのみで脆弱）。verify系フックの方がCIのgrepより確実。

## R1: 組織・アカウント

- AgencyGroup / Agency / SalesRepresentative / ContractCondition / User のCRUD
- 是正を織り込む: sales_rep_code グローバルユニーク（T-2）、契約条件は受注紐づけ前提のスキーマ（T-3）
- **Pundit policy_scope で「代理店=自代理店のみ・グループ=配下のみ」を全一覧・詳細に適用**（P4-1先取り。以降の全エンティティで必須）
- ユーザCSV一括アップロード（非同期ジョブ）
- 販売許可（Product×Agency/AgencyGroup 中間）はR2でProductと同時に

**R1見直しレビュー残タスク（2026-08-17追記）**: Agency/AgencyGroup削除時のユーザー権限昇格バグ（`dependent: :nullify`起因、重大）とCSVインポート全体パース失敗時の無言失敗は発見・是正済み（commit `1e7a0ad`）。加えて以下は見送り:
- CSVインポート結果の可視化・履歴永続化。`UserCsvImportJob`は成功/失敗件数を`Rails.logger`にしか残さず、どの行が・なぜ失敗したかを管理者がUIから確認する手段が無い。同じCSV機能である`CsvExport`（`status`/`error_message`/`row_count`列あり）と対称的な`UserCsvImport`モデル（または既存テーブルの汎用化）を追加し、`import.html.erb`に直近インポート履歴を表示する対応を推奨。

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
- PII方針（Q-D）: OrderWorkDetail/billing_password等（分類B）の暗号化は実装済みだが、Customer本体のPII（氏名・電話・メール等、分類A）を暗号化しない方針自体が`pii-handling-rules.md`/本文書に正式決定として明記されていない（実装が先行し決定記録が後追いになっている）。運用開始前に決定を文書化することを推奨。

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

## R4: 問い合わせ・通知

- Inquiry / InquiryMessage / 添付 / 宛先解決（RecipientResolver移植）
- **掲示板4種→問い合わせ統合（決定D-11・board-implementation-options.md）**: Inquiryモデルの種別別ステータスマスタ化・enum撤廃・種別×ステータス→宛先ルーティング・アフター固有列追加（2026-08-15追記: 過去データのアーカイブ投入＝R7とは別に、Inquiry拡張本体がR4に漏れていたため）
- 一斉通知（フィルタ・スケジュール送信・テンプレート・宛先グループ）
- アプリ内通知（SystemNotification + Solid Cable リアルタイム + 30日prune）
- 顧客マイページ（ログイン+ダッシュボード。Laravel現行と同等の最小構成から）

## R5: 契約フロー・決済（Laravel未実装 → 新規設計実装）

- PaymentTransaction 状態機械の忠実移植（unknown≠failed / mark・confirm分離 / 二重送信防止）+ 決済監査ログ
- **決済専用キュー＋自動リトライ無効化**（payment-integration.md §4-2: デフォルト再試行のまま流すと二重課金を自動で起こす。2026-08-15追記）
- ネットムーブ連携（payment-integration.md 準拠: リダイレクト型・HMAC-SHA256・非保持非通過・突合）
- 契約ワークフロー状態機械（不備チェック→差戻し→確認コール→契約確定）
- 契約書PDF生成・版数管理・メール送付、手書き署名
- 入力チェック設定（3段階必須）・**キーワード自動選定（P3-11。2026-08-15追記: 01§5未実装一覧にあったが計画から脱落していたため復元）**・重説チェック・申込確認メール
  - 実装順の知見（p3-12-13-confirmation-docs.md）: 重説チェックは契約ワークフロー状態機械（P3-4）より先に単独実装すると「重説未実施の案件を不備チェックへ進めてよいか」が状態機械側の論点になり手戻る。**状態機械の設計を先に固めてから重説チェックへ着手する**
- **決済状態機械（PaymentTransaction）のrequest spec必須**（2026-08-15追記: payment-integration.md §6「省略しない。タイムアウト・二重送信・改ざんは手動再現不可」の要求が完了条件に反映されていなかったため）

**R5着手前チェックリスト（2026-08-15追記）**: Q-D（PII暗号化方針）に加え、development-plan.md未確認のQ-25（返金・キャンセル業務要件）/Q-26（信販をフローに含めるか）/Q-27（決済障害時の縮退運用）の確定が必要。

## R6: 運用強化（P4群・優先度は都度判断）

- 顧客横断統合ビュー / 項目一括更新 / 顧客名寄せ（customer-merge-design.md）
  - **customer-merge-design.mdが列挙する高リスク並行処理（lockForUpdate・TOCTOU再検証・ワンタイム消費・代理店またぎ検知）はrequest spec必須**（2026-08-15追記: T-1負債対策の範囲にR6が含まれていなかったため）
- メンション / 通知一覧強化（ftlog-port.md）
- 遅延案件検知・自動キャンセル・集計レポート・外部CSV取込・ガルーン連携 等
- **CustomerStatus/OrderStatusの遷移バリデーション**（2026-08-17 R2見直しレビュー追記）: 現状は`code`がマスタに存在するかのみ検証し、不正な遷移（例: withdrawnからappliedへ戻す等）を防ぐルールが無い。R2時点ではLaravel側・Column.mdにも遷移ルールの明記が無いため許容し、本タスクとして先送り済み。R5の決済状態機械（別物）とは切り分けて設計すること。

## R7: データ移行（別プロジェクト切り出し予定）

- legacy-research/ の ETL設計・238フィールドマッピングを流用
- 掲示板42万件は参照アーカイブ（Q-C決定済み）
- **R2のスキーマ設計時点からマッピング整合を常時確認する**（移行を後から考えない）

---

## リスク・注意

1. **フェイルクローズの副作用**（新ルート追加→権限付与漏れ→全員拒否）: 起動時sync + 既定マトリクスのコード宣言 + CIガードをR0でセット導入（ftlogの再発事例に学ぶ）
2. **決済 unknown 状態の扱い**: 実装者が「わかりやすく」failedに丸めないようspecで遷移表を固定
3. **参照制御の全面適用**: R1以降の全エンティティで policy_scope 必須をレビュー観点に（CIのgrepガードで機械検出も検討）
4. Laravel側 P2 の進行と並走する場合、**要件の正は requirements/ で一元管理**し二重管理を避ける（どちらのリポジトリを正とするか運用確認）
5. PII/認証情報の暗号化方針（Q-D）はR2着手前に確定が必要

## 次のアクション

1. ~~CEOレビュー: 03の論点A〜F の確定~~ ✅ 2026-08-14 決定済み（03 §8 決定録）
2. ~~確定を反映して 03/04 を v2 に更新~~ ✅ 2026-08-14
3. **R0 着手（rails new〜認可移植）**
