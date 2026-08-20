# 掲示板4種の実装方針 判断材料（Q-C）

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/board-implementation-options.md）を
> brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて全面見直し。
> フェーズ対応: **R4**（Inquiry 拡張本体＝案①の機能実装。**実装済み**）／**R7**（過去42万件の参照専用アーカイブ投入。**未着手**）。
> Laravel時代の対応 P4-14（通知ルーティング）→ R4、P5-5（データ移行）→ R7。突合日 2026-08-19（実装: `app/models/inquiry*.rb`・
> `app/services/recipient_resolver.rb`・`db/schema.rb`・`spec/`）。突合結果は §0 に集約し、各章にも「実装済み／差分／未実装」を注記した。
>
> **ステータス: 決定済み（D-11・2026-07-26。決定者仕様意思決定）＋ R4 実装突合済み（2026-08-19）**
> 位置づけ: `business-flow-analysis.md` §11 Q-C／`development-plan.md` §8 Q-C（✅ D-11）／`04-rails-implementation-plan.md` R4「掲示板4種→問い合わせ統合（決定D-11）」・R7「掲示板42万件は参照アーカイブ」。
> 掲示板42万件（Bridge 77,981 + BridgePlus 342,594）の移行スコープは **Q-C と一体で決まる**
> （`legacy-research/09` Q-移1）。本書は3案の比較と推奨案（＝採用案①）を示し、§0 で R4 実装との突合結果を記録する。
>
> 入力: `legacy-research/03`（4種の実態・統廃合指針）／`05` §5（メール転送ルーティング）／
> `06`（BW実務でのアフター掲示板の使われ方）／`08`（移行元構造・42万件）／
> `09` C-3・Q-移1（横→縦変換・移行範囲）／`10` §6・§8-2（マッピング・サンプル検証）／
> `business-flow-analysis.md` §4・§8／実コード（Rails版: `app/models/inquiry.rb`・`app/controllers/admin/inquiries_controller.rb` 等。
> Laravel時点の参照 `app/Models/Inquiry*`・`Admin/InquiryController` は凍結された旧リポジトリに残存）

---

## 0. R4 実装突合サマリ（2026-08-19 追加）

決定D-11（案①＝問い合わせ統合）は 04 R4 で実装された。本書 §2-2 で「不足3点」とした要素を含む突合結果を示す。

| 要素 | 本書の設計（案①） | R4 実装（Rails） | 状態 |
|---|---|---|---|
| スレッド／返信 | inquiry=スレッド、messages=返信 | `Inquiry`（`order_id` NOT NULL・FK restrict）1件＝スレッド、`InquiryMessage`（`body` text・作成順）＝返信。`app/models/inquiry.rb` / `inquiry_message.rb` | 実装済み |
| 種別（掲示板4種） | カテゴリ4値 | `Inquiry::CATEGORIES` = `後確` / `制作対応` / `検収コール` / `アフター問合せ`（日本語文字列をそのまま code として保持。R7 マッピングを素直にするため） | 実装済み |
| 種別別ステータスマスタ（enum撤廃） | 掲示板種別×ステータスのマスタ | `InquiryStatus`（`inquiry_statuses`: `category`+`code` UNIQUE・`label`・`sort_order`・`is_active`・`is_system`）。`Inquiry#status` は文字列で、`InquiryStatus.exists?(category:, code:)` をモデルバリデーションで担保（DB enum/CHECK 制約なし＝ `CustomerStatus`/`OrderStatus` と同じ方式）。`StatusSeeder::INQUIRY_STATUSES` が §1 表の 8/7/6/4 値を投入（各先頭値が既定値・`is_system=true`）。管理画面 `/admin/inquiry_statuses`（CRUD） | 実装済み |
| ステータス駆動ルーティング | 「種別×ステータス→recipient_group」マスタ | `InquiryRecipientRoute`（`inquiry_recipient_routes`: `category`・`status_code`・`recipient_group_id`、3列 UNIQUE）。`RecipientResolver.route_for(category:, status_code:)` が引く。返信時に `params[:status]` があれば `Inquiry#status` を更新してから宛先解決（`Admin::InquiryMessagesController#create`）＝「ステータス選択＝宛先自動決定」。管理画面 `/admin/inquiry_recipient_routes`（CRUD） | 実装済み（**ただしルート行の初期投入なし**: `05` §5-1 のマトリクスに相当する `RecipientGroup`／`InquiryRecipientRoute` はシード未定義。運用開始前に管理画面から登録が必要 → 04 R4/R8 タスク） |
| 案件経由の宛先自動解決 | 代理店・営業・顧客をサジェスト | `RecipientResolver#resolve_from_order` → `recipients_for_inquiry` が **代理店（email_1〜5）・営業担当者・顧客のうちメールを持つ者を毎回自動的に宛先へ含め**、ルーティング結果（recipient_group）とマージ。投稿者による宛先の手動選択 UI は無い（Laravel版にあった手動選択＋サジェストは自動固定へ簡素化） | **✅ 2026-08-19 v5 CEO決定＝修正する**: `05` §5-1 では「特定ステータスのみ販売店へメール」だが、実装は**全投稿で代理店・営業担当者・顧客へメール／アプリ内通知**を送っており、`is_visible_to_agent=false` でも代理店へのメール宛先が除外されない。CEO決定により、見える範囲・ステータスに応じて宛先を絞る修正をR4追補タスクとして実施する（`notification-matrix.md` E4/E9/E10 と整合させる） |
| アフター固有フィールド | カテゴリ1-3・受電窓口・初回/次回対応者 | `inquiries.after_urgency` / `after_type` / `after_area` / `reception_channel` / `first_responder_name` / `next_responder_name`（いずれも string・任意。他種別での使用を DB では禁止しない）。`Admin::InquiriesController#inquiry_params` で受け付けるが、**新規作成フォーム（`app/views/admin/inquiries/new.html.erb`）には入力欄が未配置** | 実装済み（列）／UI 未配置。選択肢マスタ化（至急/本日中… 等の固定値）は未実装。**次回対応者によるルーティングは実装済み（2026-08-20・R4追補）**＝`inquiries.next_responder_group_id`（`RecipientGroup` 参照）を新設し、指定時はそのグループへ、未指定/無効時はステータス×ルートへフォールバックする（`RecipientResolver#next_responder_groups`）。`next_responder_name`（自由文字列）はR7移行の原文保持用に併存し、宛先解決には使わない |
| 通知（メール） | `SendInquiryMessageJob` | `InquiryMessageMailJob`（Solid Queue `default` キュー）→ `RecipientResolver.expand_for_send` で宛先展開 → `InquiryMailer#message_notification`（件名 `【問い合わせ】タイトル（INQ-xxxxxx）`、代表 to＋残り cc、添付同報、宛先単位 rescue）。成功宛先を `inquiry_message_recipients.resolved_email` に記録 | 実装済み（Laravel の heavy-processing キュー分離は無し） |
| 通知（アプリ内・既読） | SystemNotification（read_at） | `InquiryNotifier` → `SystemNotification`（`inquiry_created` / `inquiry_replied`。受信者は User／Customer。RecipientGroup は User メンバーへ展開）＋ Solid Cable（`SystemNotificationsChannel`）でリアルタイム配信、30日 prune（`config/recurring.yml`）。`mark_as_read!` あり | モデル・チャネル実装済み。**通知一覧・既読操作の画面（admin/mypage）は未実装**（R6「通知一覧強化」）。メッセージ単位既読は未実装（業務確認待ちのまま） |
| 添付 | 5ファイル×50MB | Active Storage `has_many_attached :attachments`（`InquiryMessage::MAX_ATTACHMENTS=5`・`MAX_ATTACHMENT_SIZE=50MB`。合計サイズ制限なし・MIME 制限は未実装） | 実装済み（MIME 制限は差分・小） |
| 権限 | `is_visible_to_agent`＋代理店スコープ | Pundit `InquiryPolicy`（`AgencyScoped`: 代理店=自代理店案件のみ／グループ=配下のみ。`is_visible_to_agent=false` は非スタッフに不可視）＋エンドポイント RBAC（`SystemPermission`）。起票（create）はスタッフのみ | 実装済み（代理店側からの起票 UI は R4 対象外） |
| 採番 | `INQ-000001`（count()+1） | `SequenceCounter.next_value!("inquiry_number")` による採番テーブル方式（`INQ-%06d`、最大20桁） | 実装済み（count()+1 の脆弱性は解消。ただし桁は6桁のまま＝42万件を本番投入する場合は §6 のアーカイブ別置きが前提） |
| 画面 | 一覧／詳細／起票／返信 | `/admin/inquiries`（index・show・new・create）＋ `/admin/inquiries/:id/inquiry_messages`（create）。編集・削除なし。詳細画面にステータス変更セレクト（`InquiryStatus.for_category`）。マイページ（`Mypage::DashboardController`）に問い合わせ表示なし | 実装済み（最小構成） |
| 過去42万件アーカイブ | `legacy_bbs_archives`（仮） | **未実装**（`db/schema.rb` に該当テーブルなし） | 未実装（**R7**。Q-44 の運用要件と併せて設計） |
| テスト | — | `spec/requests/admin/inquiries_spec.rb`（スコープ・可視性・作成/返信でのメールジョブ enqueue）、`spec/services/recipient_resolver_spec.rb`（`expand_for_send` / `route_for` / `recipients_for_inquiry`）、`spec/jobs/inquiry_message_mail_job_spec.rb`、`spec/models/system_notification_spec.rb` | 実装済み（`inquiry_statuses` / `inquiry_recipient_routes` の CRUD request spec は未整備） |

> 要約: **不足3点のうち「種別別ステータスマスタ」「ステータス駆動ルーティング」は R4 で実装済み**、
> 「アフター固有フィールド」は列のみ実装（UI・選択肢マスタ・次回対応者ルーティングは未実装）。
> 過去42万件のアーカイブ投入は R7。§5 の業務確認チェックリストは実装先行のため未回収（§5 参照）。

---

## 1. 掲示板4種の業務実態サマリ

現行ジャスミン内の機能（外部ツールではない）。案件番号単位のスレッドで、
**投稿ごとにステータスを選択し、それがメール通知のトリガー**になる（`business-flow-analysis.md` §4）。

| 掲示板 | 誰が | 何のために | ステータス集合 | 量の目安※ |
|---|---|---|---|---|
| 後確掲示板 | 確認コール担当（FTコール/委託先 `ecotech-order@if-n.co.jp`）・営業部・販売店 | 不備チェック・確認コールの連絡（差戻し⇄再申請のやり取り） | 対応中/営業部対応依頼/営業部対応中/後確依頼/後確NG/再申請/後確OK/キャンセル（8値） | bbs_status 列 47% |
| 制作対応掲示板 | 制作（FT運用 `bridgeplus_order@ftgroup.co.jp`）・営業部・販売店 | 作業進行中の対応依頼・進捗・共有 | 制作対応中/FT確認依頼/営業部対応依頼/営業部対応中/再申請/制作OK/キャンセル（7値） | bbs_creation_status 列 32% |
| 検収コール掲示板 | 検収コール担当・販売店 | 納品チェック完了・検収コールNGの連絡 | 検収コール対応中/検収コールNG/検収コールNG対応中/再申請/検収コールOK/キャンセル（6値） | bbs_ac_call_status 列 3% |
| アフター掲示板 | BW（業務委託）・FT管理/FT運用/FTコール・営業担当 | 納品後の解約共有・アフターフォロー・月次レポート送付記録・運用レクチャー管理 | 未対応/対応中/対応済/完了（4値）＋カテゴリ1-3＋受電窓口＋初回/次回対応者 | bbs_after_status 列 17% |

※ `legacy-research/10` §8-2 のサンプル検証（5,000行）での「値が入っている列」の内訳。
4列は**排他的に1つだけ埋まる**ことが確認済み＝列で種別判定が構造的に機能する。
（残課題: `bbs_status` の後確/制作の内部区別は列単独では不可の指摘あり。実データで要再確認）

> R4 実装との対応（2026-08-19）: 上表の4種＝`Inquiry::CATEGORIES`（`後確`/`制作対応`/`検収コール`/`アフター問合せ`）、
> ステータス集合＝`StatusSeeder::INQUIRY_STATUSES`（category ごとに上表どおり 8/7/6/4 値、各先頭値が `Inquiry::DEFAULT_STATUS_CODES`）。
> 種別・ステータスとも日本語文字列を code に採用しているため、R7 での `bbs_*_status` 列→`inquiries.category`/`status` のマッピングは値の読み替え不要。

業務上の性格の違い（根拠: `05` §5・`06` §1）:

- **後確・制作・検収コールの3種**は「案件ステータス遷移に付随する部門間連絡」。
  ステータス選択＝宛先ルーティング（`05` §5-1 の転送先マトリクス）。
  現行の非効率＝同じ情報をステータス/掲示板/基本情報備考/ガルーンに**四重で手書き**（`03` §2）。
- **アフター掲示板**だけ構造が異なり、**「分類＋対応者ルーティング付きのタスク管理」**
  （カテゴリ3軸・受電窓口・初回/次回対応者。`05` §5-2）。BW実務の中心ツールであり、
  解約対応・進捗管理・月次レポート記録・レクチャー管理がここに載っている（`06` §1）。
  `05` §5-2 は「**問い合わせ管理に近い。`inquiries` 機能への統合を検討**」と明記。
- 投稿者名は手入力文字列（`FT浅賀` 等）で**ログインユーザと未紐づけ**。1投稿2,000字上限で分割投稿あり。
- 「通知を飛ばすためだけに実態と違うステータスを選ぶ」定型運用が存在
  → 新システムでは**通知の要否とステータスを分離**すべき（`business-flow-analysis.md` §4・原則③）。
  （R4 実装では未分離: 投稿ごとに必ずメール＋アプリ内通知が発火する。`notification-matrix.md` C6 参照）

---

## 2. 既存 Inquiry（問い合わせ）実装の構造とギャップ

### 2-1. 実装済みの構造（受け皿の実力）

本節は Q-C 判断時点（2026-07-26、Laravel 実装）の評価と、R4（Rails）実装後の状態を併記する。
Rails版の実装は `app/models/inquiry.rb`・`inquiry_message.rb`・`inquiry_message_recipient.rb`・`inquiry_status.rb`・
`inquiry_recipient_route.rb`／`app/controllers/admin/inquiries_controller.rb`・`inquiry_messages_controller.rb`／
`app/services/recipient_resolver.rb`・`inquiry_notifier.rb`／`app/jobs/inquiry_message_mail_job.rb`／`app/mailers/inquiry_mailer.rb`。
（Laravel時点の参照 `app/Models/Inquiry.php` 等は凍結された旧リポジトリに残存）

| 要素 | Q-C判断時点（Laravel）の実装状況 | R4（Rails）実装状況 |
|---|---|---|
| スレッド | `inquiries`（案件 `jasmin_order_id` 必須・FK）1件＝スレッド、`inquiry_messages` が時系列の返信。**掲示板の「案件番号単位スレッド」と同型** | 同型。`inquiries.order_id`（UUID・NOT NULL・FK restrict）、`inquiry_messages` は `(inquiry_id, created_at)` index で時系列 |
| カテゴリ | `Inquiry::CATEGORIES` に **後確/制作対応/検収コール/アフター問合せ の4値が既に定義済み** | 同じ4値を `Inquiry::CATEGORY_*` 定数で保持（`inclusion` バリデーション） |
| ステータス | 未対応/対応中/対応済み/クローズ の**固定4値 enum**（DBの enum 制約）。後確8値・制作7値・検収6値は**表現不可** | **enum 撤廃済み**。`InquiryStatus` マスタ（category 単位の集合）をアプリ層バリデーションで参照 |
| 宛先 | `inquiry_message_recipients` に agency/sales_representative/customer/user/recipient_group の5型。`InquiryRecipientResolver` が案件から代理店・営業・顧客を自動解決 | 同5型（`InquiryMessageRecipient::RECIPIENT_TYPES` = Agency/SalesRepresentative/Customer/User/RecipientGroup、polymorphic）＋ `resolved_email`。`RecipientResolver` に `route_for`（種別×ステータス）を統合 |
| 通知 | メール（`SendInquiryMessageJob`・heavy-processing キュー）＋システム内通知（`CreateSystemNotificationJob`、`SystemNotification.read_at` で既読管理） | メール `InquiryMessageMailJob`（Solid Queue default）＋ `InquiryNotifier` → `SystemNotification`（同期作成、Solid Cable 配信、30日 prune） |
| 添付 | メッセージ単位で最大5ファイル・各50MB・MIME 制限 | Active Storage で 5×50MB（MIME 制限は未移植） |
| 権限 | `is_visible_to_agent` フラグ＋代理店/代理店グループのアクセススコープ（`applyAccessScope`） | `is_visible_to_agent` ＋ Pundit `InquiryPolicy`（`AgencyScoped`）＋エンドポイント RBAC |
| 採番 | `INQ-000001` 自動採番（`count()+1` 方式。**42万件流し込みには採番方式の見直しが必要**な点に注意） | `SequenceCounter` 採番テーブル方式に変更済み（`INQ-%06d`） |

### 2-2. 掲示板要件とのギャップ表

| 観点 | 掲示板要件（現行） | Inquiry 実装（Q-C判断時点） | ギャップ | R4 での解消状況（2026-08-19） |
|---|---|---|---|---|
| スレッド構造 | 案件単位・`parent_bbs_id` で親子返信 | inquiry=スレッド、messages=フラット返信 | **小**。親子→「スレッド＋返信」への写像で吸収可（`latest_flg` は導出可能） | 変更なし（フラット返信のまま。R7 で写像） |
| ステータス | 種別ごとに異なる集合（8/7/6/4値）・**掲示板種別×ステータスのマスタが必要**（`03` §1） | 固定4値の DB enum | **大**。enum 撤廃→種別別ステータスマスタ化が必須 | **解消（実装済み）**: `InquiryStatus`＋`StatusSeeder` |
| 通知ルーティング | **ステータス（or 次回対応者）選択＝宛先自動決定**（`05` §5 のマトリクス） | 投稿者が宛先を手動選択（自動サジェストはあり） | **中**。「種別×ステータス→recipient_group」のルーティングマスタを足せば P4-14 と同一機構に載る | **ステータス側は解消（実装済み）**: `InquiryRecipientRoute`＋`RecipientResolver.route_for`。**次回対応者側は未実装**（`05` §5-2）。マトリクス相当のルート行は未シード。宛先の手動選択は廃止（自動固定） |
| アフター固有 | カテゴリ1-3（緊急度/種別/領域）・受電窓口・初回/次回対応者 | category 1列のみ | **中**。列またはメタデータ追加が必要 | **列は実装済み**（`after_urgency`/`after_type`/`after_area`/`reception_channel`/`first_responder_name`/`next_responder_name`）。フォーム UI・選択肢マスタは未実装 |
| 添付 | あり（現行は合計10MBバグ） | あり（5×50MB） | なし（改善済み） | 同左（Active Storage） |
| 既読 | P4-14 で既読管理を要求（`06` §1-②） | SystemNotification に read_at | **小**。通知単位の既読はあり。メッセージ単位既読が要るかは業務確認 | `SystemNotification#mark_as_read!` あり。一覧・既読 UI は未実装（R6）。メッセージ単位既読は業務確認待ちのまま |
| 投稿者 | 手入力文字列（未紐づけ） | created_by=ログインユーザ FK | 新規投稿は改善。**過去分の移行時のみ名寄せ問題**（`09` C-5・Q-移2） | 同左（`TracksUser` で `created_by_id`）。名寄せは R7（`name-matching-process.md`） |
| ステータス変更とセット操作 | ステータス変更→掲示板記載→備考記載→ガルーンの四重手作業（`03` §2） | 返信時にステータス同時更新は可能 | **中**。案件ステータス遷移との自動連動（`03` §2-1 のセット操作自動化）は別途 P3 側の設計 | 返信時のステータス同時更新は実装済み。**案件（Order）ステータス遷移との連動は未実装**（R5 契約ワークフロー状態機械／R6 遷移バリデーションの設計課題） |
| 文字数 | 1投稿2,000字上限（分割投稿の温床） | text 型・実質無制限 | なし（改善） | 同左（`body` text） |

> 結論: **Inquiry は「掲示板の受け皿」として設計上すでに半分準備されている**
> （カテゴリ4値の存在・案件必須・宛先解決・通知/既読/添付の基盤）。
> 不足は「種別別ステータスマスタ」「ステータス駆動ルーティング」「アフター固有フィールド」の3点に集約される。
> → **R4 で前2点は実装完了、3点目は列のみ実装**（§0）。

---

## 3. 3案比較表

（Q-C 判断時点の比較。案①を D-11 で採用し R4 で実装済み。②③は不採用の記録として保持）

| 評価軸 | ① 問い合わせ統合（Inquiry を掲示板対応に拡張）**【採用・R4実装済み】** | ② 独立実装（掲示板専用の新機能・新テーブル）【不採用】 | ③ 現行維持（新システムでは実装せず外部ツール継続）【不採用】 |
|---|---|---|---|
| 実装コスト | **中**。スレッド/返信/宛先/通知/添付/権限は流用。追加＝種別別ステータスマスタ（enum撤廃）・種別×ステータス→宛先ルーティング・アフター固有列・採番方式見直し | **高**。テーブル・画面・通知・権限・添付を新規に一式。しかも inquiries と機能重複（連絡系が2系統） | **低**（新規実装ゼロ）。ただし現行ジャスミンはリクリック保守で退役予定のため、実質は「旧システムを掲示板のためだけに延命」または「ガルーン等へ載せ替え」＝載せ替えなら移設作業が発生 |
| 移行コスト（42万件の行き先） | **中**。行き先が inquiries/inquiry_messages に一本化。C-3 縦持ち変換の着地点が明確。ただし全件を本番テーブルへ入れると採番・性能・名寄せ（Q-移2）が重い → §6 の段階案と組み合わせるのが前提 | **中**。現行34列構造に忠実な専用スキーマにできる分マッピングは素直だが、C-3・名寄せ・42万件の性能問題は①と同じ。テーブル定義が Q-C 確定後に一から必要（`10` §6） | **極小〜ゼロ**。42万件の移行自体が不要（Q-移1=移行しない）。ただし過去ログ参照のため旧システムか退避CSVの閲覧手段を残す必要 |
| 業務影響（現行運用からの変化） | **中**。画面と操作は変わるが「案件スレッド＋ステータス選択＝通知」の業務概念は保存。四重管理（`03` §2-2）を1回の記録に集約できる＝内製化の狙いに合致 | **小**。現行の見た目・概念をほぼ踏襲可能。ただし「通知目的の偽ステータス」等の現行の歪みを再生産するリスク（`business-flow-analysis.md` §4 の警告） | **大**。案件管理は新システム・部門間連絡は別システムに分裂。案件との紐づけ（target_id 相当）が切れ、四重管理が恒久化。`business-flow-analysis.md` §8 は掲示板を「✅統合する」と判断済みで、これに反する |
| P4-14（R4）通知ルーティングとの整合 | **高**。「掲示板種別×ステータス→宛先」マスタ＝実装済み `recipient_groups`＋通知テンプレートに直結（`05` §5 の設計示唆どおり）。既読管理（SystemNotification.read_at）も共用 | **中**。同じルーティングマスタを別系統から参照する形になり、通知経路が inquiries と二重化 | **低**。通知が新システムの外で発生し、P4-14 の一元的な通知一覧・既読管理に載らない |
| 保守性 | **高**。連絡系が1系統。ステータスマスタ駆動で種別追加にも耐える | **低〜中**。連絡系2系統の二重保守。「問い合わせと掲示板のどちらに書くか」問題が発生 | **低**。旧システム延命 or ガルーン依存。仕様変更・権限で止まるリスク（`03` §2-2 と同種） |

---

## 4. 移行への影響（Q-移1 との接続）

Q-移1「掲示板42万件の移行範囲（全件/直近/アーカイブ別置き）」は案ごとに次のように変わる。
（採用は①＋§6 段階案。実装フェーズは **R7**（データ移行・別プロジェクト切り出し予定）。以下は判断記録として保持）

| 案 | 移行スコープ | C-3（横→縦）| 名寄せ（Q-移2） | 備考 |
|---|---|---|---|---|
| ① 統合【採用】 | 選択制: 全件 or 直近N年 or アーカイブ別置き。**全件を本番 inquiries に入れるのは非推奨**（採番・スレッド表示性能・created_by FK の名寄せ精度。`09` C-3-5 の性能懸念） | 必要（着地スキーマは確定済みの inquiries 系。R4 実装の `inquiries`/`inquiry_messages`/`inquiry_statuses` が正） | 本番投入分のみ必要。アーカイブ分は文字列のまま保持可 | §6 の段階案と組むと名寄せが移行の律速から外れる |
| ② 独立 | 同上（選択制）。専用スキーマなら現行構造に近く全件移行が最も素直 | 必要（着地スキーマは Q-C 確定後に新規定義。`10` §6） | 同上 | テーブル定義の待ちが1段増える |
| ③ 現行維持 | **移行不要（0件）**。P5-5 から掲示板系（C-3・V-5・V-6 の掲示板分・名寄せ表の掲示板分）が丸ごと消える | 不要 | 不要 | 代わりに「過去ログの参照手段」（旧システム延命 or 退避CSV閲覧）の恒久運用が必要。案件詳細から過去経緯を追えなくなる業務コストが残る |

P5-5（→R7）の律速3点「**Q-C（掲示板限定）＋現行DB再エクスポート＋名寄せ表**」（`development-plan.md`）のうち、
①＋段階案（§6）を取ると **名寄せ表の掲示板分が「本番投入する直近分のみ」に縮小**し、
律速が実質「Q-C 確定＋再エクスポート」に軽くなる。Q-C は D-11 で確定済みのため、R7 の律速は「再エクスポート＋Q-44（アーカイブ運用要件）」に移った。

---

## 5. 推奨案

**推奨: 案①（問い合わせ統合＝Inquiry の掲示板対応拡張）＋ §6 の段階移行（新規=新システム、過去42万件=参照専用アーカイブ）。**
→ **2026-07-26 D-11 として採用。案①本体は R4 で実装済み（§0）、段階移行（アーカイブ）は R7。**

根拠:

1. **受け皿が既に半分できている**: `Inquiry::CATEGORIES` は掲示板4種そのもの。スレッド・宛先解決・
   recipient_groups・通知・既読・添付・代理店権限が実装済みで、不足は3点（種別別ステータスマスタ／
   ステータス駆動ルーティング／アフター固有フィールド）に集約される（§2-2）。
2. **調査ノートの設計示唆と一致**: `05` §5-2「アフター掲示板は問い合わせ管理に近い。inquiries への統合を検討」、
   `business-flow-analysis.md` §8「掲示板4種 ✅統合する」、同 §10 原則②「同じ情報を2箇所に持たない」。
3. **P4-14（R4）と同一機構**: 「種別×ステータス→宛先」マスタは P4-14 の通知ルーティングそのもので、
   独立実装（②）だと同じマスタを2系統から使う歪みが出る。
4. **③は内製化の目的（二重管理の解消・`06` §4）に真っ向から反する**: 四重管理の恒久化＋案件との紐づけ喪失。
   移行コストゼロの魅力はあるが、掲示板は現行ジャスミン内の機能であり「維持」には旧システム延命が要る。

**ただし業務影響が中程度あるため、以下を業務側（浅賀さん等）／決定者 に確認して確定する:**
（2026-08-19 注: R4 は本チェックリスト未回収のまま実装先行した。実装は「全部保持・厳格な制約なし」で進めているため、
確認結果次第で UI・バリデーション・シードを追補する。04 R4 未実装ギャップ／R8 UAT で回収すること）

- [ ] 後確/制作/検収の3掲示板を「問い合わせ」画面系に載せて業務が回るか（呼称・画面動線）
      — R4 実装: 管理画面メニュー名は「問い合わせ」、新規作成フォームのラベルは「掲示板種別」（`new.html.erb`）。呼称は未確定
- [ ] アフター掲示板のカテゴリ3軸・受電窓口・初回/次回対応者は全部必要か（統廃合余地）
      — R4 実装: 6列すべて保持（任意・自由文字列）。選択肢の固定値化・フォーム配置は確認後に実施
- [ ] 「通知目的のステータス」（営業部対応依頼等）を通知機能に分離してよいか（`03` §1 の方針確認）
      — R4 実装: 未分離（全投稿で通知発火）。`notification-matrix.md` C6 参照
- [ ] 過去42万件は参照専用アーカイブでよいか（§6。検索要件・保持期間）
      — `development-plan.md` §8 Q-44 として別建て。R7 着手前に確定
- [ ] `bbs_status` の後確/制作の内部区別（`10` §8-2 の残課題）の実データ確認 — R7（再エクスポート後）
- [x] （2026-08-19 追加）全投稿を代理店・営業担当者・顧客へ自動送信する現行実装でよいか（§0「差分」）
      → **✅ 2026-08-19 v5 CEO決定＝修正する**。見える範囲・ステータスに応じて宛先を絞る（R4追補タスク）
- [ ] （2026-08-19 追加）**外部委託先アドレス**（`ecotech-order@if-n.co.jp` 等）の宛先化方法。
      `RecipientGroupMember` は User／ProductionCompany のみ（管理画面 UI は User のみ）のため、委託先用の User または ProductionCompany レコードを作る運用でよいか（G-7 委託先連携）

---

## 6. 段階案の検討: 「新規は新システム・過去42万件は参照専用アーカイブ」

**結論: 成立する。むしろ①の前提として推奨。**（D-11 で採用。実装は **R7・未着手**。`db/schema.rb` に `legacy_bbs_archives` は未定義）

| 項目 | 内容 |
|---|---|
| 構成 | カットオーバー後の投稿は新システム（拡張 Inquiry＝R4 実装済み）で完結。過去42万件は **`legacy_bbs_archives`（仮）専用テーブル**に読み取り専用で投入し、案件詳細画面に「過去掲示板（参照）」タブで表示 |
| アーカイブのスキーマ | C-3 の縦持ち正規化（種別判定・スレッド復元）は行うが、**名寄せをしない**: 投稿者/対応者は手入力文字列（`FT浅賀`等）のまま保持。旧 `bbs_id`・`parent_bbs_id`・`target_id`（→新案件 `orders.id`（UUID）解決のみ必須）を保持。PK は他テーブル同様 UUID |
| 成立根拠 | (a) 過去投稿の用途は「経緯の参照」であり編集・返信は不要（現行でも過去スレッドに書き足す運用はステータス駆動で新規投稿が基本）。(b) `10` §8-2 で種別判定の排他性がサンプル検証済み＝機械変換可能。(c) 本番 inquiries を汚さないので採番・ステータスマスタ・性能・FK 制約と無縁 |
| 効果 | 42万件の**名寄せ（Q-移2）が移行の律速から外れる**。V-6（名寄せ未一致）検証はアーカイブ対象外。スレッド表示性能懸念（`09` C-3-5）解消。ETL は rake タスク／`rails runner`＋チャンク処理（Laravel時代の Artisan 前提を読み替え。`09` §6-2）でそのまま流せる |
| 残コスト | C-3 の種別判定・スレッド復元・2,000字分割投稿の再構成・旧案件ID→新IDの解決は残る（ここは③以外どの案でも必要） |
| バリエーション | 「直近1年分だけ本番 inquiries にも投入（対応継続中のアフター案件など）＋残りはアーカイブ」の折衷も可。対応中スレッドの断絶が業務上許容できるかで判断（要業務確認）。本番投入する場合は `Inquiry` の種別・ステータス code が日本語文字列のため値変換不要だが、`created_by_id`（User FK）の名寄せ（`name-matching-process.md`）が必要 |
| リスク | 検索が新旧2箇所に分かれる（アーカイブ側にも案件番号・全文検索（pg_bigm）を付ければ緩和）。「過去分に返信したい」要望が出た場合はアーカイブから新スレッドを起こす運用で対応 |

---

## 7. 反映先（Q-C 確定後）

| 反映先 | 内容 | 状態（2026-08-19） |
|---|---|---|
| `legacy-research/10` §6 | 新テーブル定義（拡張 inquiries or legacy_bbs_archives）を確定させマッピングを完成 | 拡張 inquiries は R4 で確定（`db/schema.rb`）。`legacy_bbs_archives` は R7 で定義 |
| `legacy-research/09` C-3・Q-移1 | 移行範囲の確定（本書 §6 の段階案採否） | 段階案採用（D-11）。運用要件は Q-44 |
| `04-rails-implementation-plan.md` R4（旧 `development-plan.md` P4-14） | 種別×ステータス→宛先ルーティングマスタの実装に本書 §2-2 を入力 | 反映済み・実装済み（`InquiryRecipientRoute`） |
| `04-rails-implementation-plan.md` R7（旧 `development-plan.md` P5-5） | 律速解除（掲示板系テーブル定義の着手） | R7 未着手 |
| `notification-matrix.md` E9/E10 | Q-C 確定後の再検証（同書の注記11） | 2026-08-19 に実装突合済み版で再検証（同書 §1・§3-11） |

---

## 8. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-26 | 初版。掲示板4種の業務実態・Inquiry 実装のギャップ・3案比較・段階案を整理。推奨=①統合＋参照専用アーカイブ（決定者/業務確認で確定） |
| 2026-07-26 | D-11 として案①＋段階移行を採用（`development-plan.md` §8 Q-C ✅） |
| 2026-08-19 | Rails版改訂。R4 実装（`Inquiry`/`InquiryStatus`/`InquiryRecipientRoute`/`RecipientResolver`/`InquiryNotifier`/`InquiryMessageMailJob`）との突合結果を §0 に追加、§2/§5/§6/§7 に実装済み／差分／未実装（R7）を注記。Laravel 固有記述（`app/Models/*.php`・Artisan・enum）を Rails 版へ読み替え。§5 に確認事項2件（全投稿の顧客・代理店自動送信／外部委託先アドレスの宛先化）を追加 |
