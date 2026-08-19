# review-05: 旧Laravelプロジェクト設計ドキュメント一式の移植レビュー

- 対象: `/home/fujisawa/project/ai-auto-company/projects/boilerplate-vue-env/laravel/requirements/design/` 配下30ファイル + `requirements/development-plan.md`（計31ファイル）を `brige-crm/requirements/` 配下へ2026-08-19にそのままコピー
- 方法: 9グループに分けて並列エージェントで精読。各ファイルについて (1)概要 (2)Laravel固有実装詳細の有無 (3)関連フェーズ (4)03/04との矛盾・重複 (5)推奨アクション を確認
- 本ファイルは調査結果の集約。**04-rails-implementation-plan.mdへの反映はこの後の別コミットで実施**（本レビュー自体はコピーしたファイルの棚卸しのみ）

---

## 1. 重要度高（要対応・要確認）

### 1-1. R5着手前チェックリストの未解決論点（裏付け確認）
`04-rails-implementation-plan.md`のR5着手前チェックリストが挙げるQ-25(返金・キャンセル)/Q-26(信販)/Q-27(決済障害時縮退運用)は、一次ソースである `development-plan.md`§8 で依然「未確認」のままと確認できた。加えて `development-plan.md`§8には04未記載の関連未決論点が多数残存:
- Q-35: 重説チェック・確認書の未決事項（項目/実施者/タイミング/宛先/版管理） — `contract-confirmation-docs.md`のQ-1〜9と重複
- Q-36〜39: 決済トランザクション紐づけ単位・jutyu_cd桁数・決済結果確定手段・ステージング検証方式
- `payment-integration.md` D-P8「継続課金の売上処理はTBSSスコープ外、新システムは請求用受注データCSV出力のみ」の04本文への反映漏れ（R5本文にもR6のCSV汎用化(export-profile-design.md)にも明記なし）

**推奨**: R5着手前チェックリストにQ-35〜39とD-P8の着地確認を追加する。

### 1-2. ステータス呼称の実装不整合（status-naming-analysis.md）
`status-naming-analysis.md`のQ-B（案A: 「案件ステータス」「申込ステータス」「契約ステータス」の3語確定）について、実装を確認したところ `order_statuses` 側は案A準拠（「案件ステータス」）だが、`customer_statuses` 側は`app/views/admin/customer_statuses/index.html.erb`等で依然「顧客ステータス」のまま。案Aが**中途半端に適用された状態**で放置されている。03/04にはこの呼称統一に関する決定記録がない。

**推奨**: `customer_statuses`関連の表示文字列（ビュー・通知フィルタラベル等）を「申込ステータス」に統一するタスクを04に追記し、R5前後の早い段階で解消する。

---

## 2. 04への新規タスク追記候補

| 出典 | 内容 | 想定フェーズ |
|---|---|---|
| `business-flow-analysis.md` | G-1(商材別納品日)〜G-9の既存実装との差分。特にG-1は請求ルール(§7)に関連 | R5/R6 |
| `export-profile-design.md` | P4-12: CSVエクスポートの複数プロファイル対応・汎用化（設計思想=config管理・列カタログのホワイトリスト化は移植価値あり） | R6 |
| `netmove-card-migration.md` | `netmove_member_id`取り込みETL枠、会員ID採番の新旧両対応、カード変更(member-modify)導線 | R5/R7 |
| `notification-matrix.md` | E6(決済失敗)/E8(自動キャンセル)等、個別受信者ルールが「?要確認」のまま実装が先行した形跡。R5/R6着手前に整合確認要 | R5/R6着手前 |
| `name-matching-process.md` | 名寄せ手順（機械マッチング→人手確認→レビュー→版確定ループ、精度目標97%）がR7の一次資料として未参照 | R7 |
| `remaining-tasks.md` 7-1 | 未収情報フィールド（売上伝票番号・未回収額等）が現行schemaに見当たらず04にも未記載 | R2追加 or R6 |
| `legacy-research/13-faq-templates.md` | R4の`notification_template.rb`はtemplate_type区分のみで、FAQ12カテゴリマスタ・差し込み変数・テンプレ選択UIは未実装（機能ギャップ、矛盾ではない） | R4後続 or R7 |

---

## 3. 要確認（実装済みかどうかの突合が必要）

- `form-template-mapping.md`: 設計思想（target_table/target_column等）は既に03/04・R3実装に反映済みと推測されるが、§2の個別フィールドリスト（BRIDGE_PLUS向け155項目）とR3実装済みFormField定義の突合は未実施。フレームワーク部分は再実装不要、未反映フィールドのみ抽出すべき。

---

## 4. そのまま参照可（追加アクション不要）

- `Column.md` — R1/R2実装の一次資料。03/04が直接引用済み
- `board-implementation-options.md` — 04のR4記述（決定D-11）の根拠文書そのもの
- `customer-merge-design.md` — R6着手時にそのまま設計インプットとして使える
- `payment-integration.md` — Laravel固有記述（Horizon等）以外の状態機械・外部API仕様・冪等性設計はR5設計の必須参照
- `pii-handling-rules.md` — 3分類の運用ルール自体は参照可（ディレクトリパスのみRails版に合わせて書き直し要、Q-D決定の反映も要）
- `release-readiness.md` — R8のA〜J構成の枠組みとして継続活用。個別項目のうちDB/キュー/監視スタック記述（特にA-1「MySQL」）はLaravel側限定の決定であり無視すること
- `basic-design.md` §1-5/15-18 — 実装済み確認程度。§6-14（申込登録〜契約書作成）はR5設計の一次資料として着手時に精読

---

## 5. 古くなっており実質不要（アーカイブ扱いでよい）

- `Inquiry-email.md` — 大部分がR4実装・03/04決定で上書き済み。PK方式(AUTO_INCREMENT→UUID)・権限方式(Spatie→Pundit)・ステータス方式(enum固定→マスタ化)が全て変更済み。「JasminCustomerをContract等へリネーム」提案は03§8-2でCTOが明示的に却下済み
- `ftlog-port.md` — 「Rails(ftlog)→Laravelへの逆輸入」文書のため、Rails版では直接ftlogを移植すればよく本書のLaravel変換記述は不要。決定事項(Q-16〜23)自体はR0/R4で実装済み
- `branch-merge-policy.md` / `test-file-review.md` — Laravel版リポジトリの一過性の運用記録。転用価値なし
- `test-code-plan.md` — 方法論は参考になるが、brige-crmは既にFactoryBot 33件・Pundit・`authorization_guard` CIで本書の目標を上回る形で先行実装済み
- `remaining-tasks.md` — 文書自身が「development-plan.mdが正」と自己申告済み（2026-07-27追記）。7-1のみ上記2章に記載の通り価値あり
- `basic-cost.md` — MySQL/ElastiCache/Horizon前提で03決定A(PostgreSQL)・Solid Queue/Cache/Cable(Redisレス)と矛盾。R8のインフラ確定時にPostgreSQL/Redisレス構成で再試算が必要

---

## 6. legacy-research/（16ファイル、R7領域）

全ファイル精読済み。**現行R2実装済みスキーマ（Customer/Store/Order/Plan等）と致命的に矛盾する記述は無し**。R7（データ移行、別プロジェクト切り出し予定）着手時まで待機でよい。既知課題として以下が残存（新規発見ではなく、各ドキュメント自身が既に課題として記録済みのもの）:

- Q-移7: `agencies`に住所・電話カラムが無い（代理店の住所管理要否は未決）
- Q-移15/18: 月額料金のスナップショット保存要否、契約単位(168)/初期構築(169)フィールドの対応先未定
- DM-7: 旧システムの「施工担当者」概念が新スキーマに存在しない（R1組織領域の要否確認事項）
- G-1相当: `work_completed_at`が商材別に分離されておらず単一カラムのまま

いずれもR7設計時に一次資料として使えば足りる。

---

## 次のアクション

1. 1-1/1-2（重要度高）をCEO/業務側に確認し、R5着手前チェックリストへ反映
2. 2章の新規タスク候補を04-rails-implementation-plan.mdの該当フェーズへ追記
3. 3章のform-template-mapping.md突合を実施
4. 5章の「実質不要」ファイル群は`requirements/design/`に残置したままでよい（削除は不要。参照時に本レビューで判断済みである旨がわかればよい）

---

## 追記（2026-08-19・同日後続作業）

- 上記「次のアクション」1〜3 は同日中に完了。全設計ドキュメントを Rails 版へ全面改訂し（`review/review-06-rails-revision-sweep.md`）、突合結果を `04-rails-implementation-plan.md` v4 へ反映した。
- 3章の `form-template-mapping.md` 突合は実施済み: 「155項目」は概数で field_key 実数は 67 件、**全件未投入**（保存先カラムは全て実在。同書 §9）。
- 1-2 の Q-B は `development-plan.md` §8 の D-8（2026-07-26）で**決定済み**と判明（未決ではなく適用漏れ）。04 v4 に決定として記録済み。
- リネーム: `p3-12-13-confirmation-docs.md` → `contract-confirmation-docs.md`、`notification-matrix-draft.md` → `notification-matrix.md`（本文中の参照は置換済み）。
