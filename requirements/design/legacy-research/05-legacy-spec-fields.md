# 現行仕様書のフィールド定義 調査

> Rails版改訂: 2026-08-19。旧Laravelプロジェクト（boilerplate-vue-env/laravel/requirements/design/legacy-research/05-legacy-spec-fields.md）を brige-crm（Rails 8.1）の現行実装・03/04 の決定に合わせて見直し。フェーズ対応: R2（`orders` 受け皿・`OptionGroup`）／R3（`FormField` の3次元編集権限）／R4（掲示板ルーティング）は実装済み、R5（サイン画像・契約）は未実装、R7（旧フィールド→新カラムの移行）。現行仕様書のフィールド定義・選択肢・転送先アドレスは不変。旧テーブル名（`jasmin_orders`）・旧クラス名（`FormTemplateDefinition`）・削除済み `ftlog-port.md` への参照のみ Rails 版へ差し替えた。
>
> 出典: `01.ジャスミン現状設計書/【BridgePlus】ジャスミン仕様書20251118.xlsx`
> シート: 電子契約作業項目88 / 基本情報98 / 作業項目110 / 掲示板51 / 掲示板転送先設定33
> 位置づけ: 現行の**正式フィールド名・選択肢の完全リスト・編集権限・掲示板ルーティング**。
> P2（申込フォーム）・P3（契約フロー）・P4（通知・権限）の実装入力。

---

## 1. ⚠️ 最重要：3次元の編集権限（項目 × 階層 × ステータス）

現行ジャスミンの編集権限は**単純なロールではなく、3つの軸の組み合わせ**で決まる。
これは新システムの権限設計（P4-1）に大きく影響する、見落とせない仕様。

### 軸1：組織の階層（第一階層 / 第二階層以下）

フィールドごとに編集可否が違う。代表例：

| 編集権限パターン | 例 |
|---|---|
| 第一階層のみ編集可、第二階層以下は不可 | 顧客番号・受注日・契約開始日・計上月・システムアカウントID 等（大半） |
| 全ての階層で編集可 | 発注日・高齢者同意書・おまとめ請求・顧客ステータス・プラン・初期費用 等 |
| 編集不可（自動入力のみ） | 顧客番号・案件番号・月額料金・同意状況・サイン画像 |

### 軸2：ステータスによる編集ロック

多くのフィールドに「**"6-1:確認コール済（作業進行保留)" 以降は第二階層以下は不可**」等の条件。
つまり**案件が進むと編集がロックされる**。ステータスが編集可否を動的に変える。

- 顧客ステータス：「16:完了」以降は第二階層以下不可、「6-1」のみ第二階層以下は変更不可
- 確認コール系：「3:確認コール架電待ち」以降は第二階層以下不可

### 軸3：項目そのものの入力形式

自動入力（他項目/他テーブルから転記）・フリーワード・プルダウン・日付・レ点・添付。

> **設計への示唆**：新システムでは「フィールド定義」に
> `editable_by_tier`（第一階層のみ/全階層）× `lock_after_status`（このステータス以降ロック）
> のメタデータを持たせる必要がある。旧Laravelでは `FormTemplateDefinition` の拡張（P2-1）として提案。
> **単純なロールベース権限だけでは現行を再現できない**。
>
> **brige-crm 実装状況（R3 実装済み・2026-08-19 突合）**: `FormField`（`form_fields`）が
> `editable_by_tier`（string 配列・GIN index。`FormField::TIERS = sales_representative / agency / admin`）と
> `lock_after_status`（`order_statuses.code` を参照・存在検証あり）を初期スキーマから持つ（03 §5「P2拡張後仕様を初期スキーマに採用」）。
> `FormField#locked_for?(order)` が `OrderStatus.sort_order` でロック判定する。
> - 現行の「第一階層/第二階層以下」は brige-crm では **tier（sales_representative / agency / admin）＋ Pundit の代理店・グループスコープ**で表現する。
> - `lock_after_status` を実際に効かせる再編集フロー（申込後の項目編集）は **R5 で実装**（R3 は新規申込のみ）。
> - `../form-template-mapping.md` §2 が列挙する BRIDGE_PLUS 向け個別フィールド155項目と `FormField` 定義の突合は未実施（04 R3 要確認）。

---

## 2. 基本情報フィールド（orders 実装との対応）

現行「基本情報」は実装済み `orders`（旧 `jasmin_orders`。決定 D により `jasmin_` プレフィックス除去、モデル `Order`。**R2 実装済み**）とよく対応している（Column.md の設計品質は高い）。下表の実装カラムは 2026-08-19 に `db/schema.rb` と突合済み。

| 現行フィールド | 実装カラム | 備考 |
|---|---|---|
| 会員管理ID | `member_id` | ✅ |
| 請求パスワード | `billing_password` | ✅ |
| MEO施策管理番号 | `meo_mgmt_number` | ✅ |
| 発注日 | `issued_at` | ✅ |
| アカウント発行日 | `account_issued_at` | ✅ |
| 作業完了日（納品完了メール送付日） | `work_completed_at` | ⚠️ **商材別に分離が必要**（G-1） |
| 計上月 | `accounting_month` | ✅ |
| 検収コールNG時間帯 / 履歴 / 完了日 | `inspection_call_*` | ✅ |
| 決済回収日 / 決済書類確認日 | `payment_collected_at` / `payment_doc_confirmed_at` | ✅ |
| 高齢者同意書 / 回収日 | `elderly_consent*` | ✅ |
| 業務権限証明書 / 回収日 | `business_auth_doc*` | ✅ |
| おまとめ請求 / おまとめ先案件番号 | `bundled_billing` / `bundle_target_order_number` | ✅ |
| システムアカウントID / PASS | `order_work_details.system_account_id` / `system_account_pass` | ✅ R2 実装済み（`ActiveRecord::Encryption` `encrypts`・text 列。`pii-handling-rules.md` 分類B）。メールアドレス/パスワードを自動入力 |

### 2-1. 新規に必要そうなフィールド（実装未確認）

| 現行フィールド | 用途 | brige-crm 状態（2026-08-19 突合） |
|---|---|---|
| 伝票番号（発送用）/（返送用） | ファクター（口座振替用紙）の発送・返送管理 | **未実装**（`orders` に該当カラム無し。`sales_mgmt_slip_number` は販管の売上伝票番号で別物）。R5（決済・請求）または R7 マッピング（`11` 参照）で要否判断 |
| ファクター回収備考 | 口座振替用紙の回収メモ | ✅ `orders.factor_notes`（string 200）R2 実装済み |
| 履歴記載枠（運用） | 運用履歴の自由記載 | ✅ `order_work_details.operation_history`（text）R2 実装済み |
| 管理者メールアドレス / 店舗メールアドレス | ※複数入力時は「;」区切り | `customers.email`（Devise ログインID・一意）のみ。店舗側 `stores` にメール列**無し**。「;」区切り複数メールの受け皿は未実装 → R7 マッピング時に要否判断（`11`） |
| サイン画像 | **電子契約の手書き署名画像**（編集不可・自動取得）→ P3-3 | **R5 未実装**（契約書PDF・手書き署名。Active Storage 添付で実装想定） |
| 同意状況 / 同意時 代表者年齢 / 担当者年齢 | 電子契約の同意記録 | ✅ `orders.consent_status` / `consent_rep_age` / `consent_contact_age` R2 実装済み |

---

## 3. 添付欄の仕様（現行のバグに注意）

| 項目 | 現行仕様 |
|---|---|
| 添付欄 | 1〜5の5枠 |
| 1ファイル上限 | 3MB（超過で「1ファイル3Mバイト以下です」アラート） |
| 合計上限 | **10MB超で「エラーとバグが発生」** ← 現行の欠陥 |

> **新システムでは合計サイズ制限を正しく実装**（現行はバグとして明記されている）。
> ファイルは S3 保存（`release-readiness.md` A-8）。
>
> **brige-crm 実装状況（R4 実装済み）**: 添付は Active Storage（`InquiryMessage has_many_attached :attachments`、
> `Notification` も同様）。`InquiryMessage::MAX_ATTACHMENT_SIZE = 50MB`（1ファイル）＋件数のガードのみで、
> **合計サイズ制限は意図的に設けていない**（direct upload と相性が悪いため。`app/models/inquiry_message.rb` 冒頭コメント）。
> 現行の「1ファイル3MB／5枠」より緩い。ストレージ本番先（S3 等）は R8 で確定。

---

## 4. 電子契約 作業項目（選択肢の完全リスト = P2-5 の元データ）

`business-flow-analysis.md` §5 の155項目と重複するが、こちらが**選択肢の正**。
特に **属性1〜11** の選択肢は OptionGroup シーダー（P2-5）にそのまま使える。

### 4-1. 属性1〜11（GBP掲載属性・レ点・複数選択）

| 属性 | 主な選択肢（抜粋） |
|---|---|
| 属性1 | 女性経営者のビジネスと確認された / 該当なし |
| 属性2 | 車椅子対応（エレベーター/トイレ/入り口/座席/駐車場）/ 該当なし |
| 属性3 | 無料/有料Wi-Fi・トイレあり・バー併設・子ども用椅子・禁煙 等 |
| 属性8 | **飲食系40項目超**（アルコール・カクテル・キッズメニュー…宅配・当日配達 等） |
| 属性9 | **決済手段**（NFC・クレカ[AMEX/Diners/Discover/JCB/MasterCard/VISA/中国銀聯]・デビット・小切手・現金のみ）/ 該当なし |
| 属性10 | 特定患者検査対応・紹介状必要・要予約・予約可 / 該当なし |
| 属性11 | イートイン・テイクアウト・テラス席・ドライブスルー 等 |

> ⚠️ **属性はGoogle側の仕様に追随する**（GBPの属性リストが変わると更新が必要）→ Q-H（既出）。
> OptionGroup として持つが、**保守運用（Google仕様変更時の更新）を前提**にする。
>
> **brige-crm 実装状況（R2 実装済み）**: `OptionGroup`（`option_groups.key` 一意）／`OptionValue`（`parent_id` 方式のツリー・`depth`・
> グループ内 `value` 一意・循環/グループ越境防止バリデーション）＋管理UI `Admin::OptionGroupsController` / `OptionValuesController`。
> 属性値の受け皿は `order_work_details.attribute_1〜11`（string 100）。ただし **本節 §4-1/§4-2 の選択肢を投入するシーダーは未作成**
> （`StatusSeeder` はステータスのみ）。旧 P2-5「OptionGroup シーダー化」は R7 の初期データ投入または R6 で実施（要判断）。

### 4-2. その他の主要選択肢

| 項目 | 選択肢 |
|---|---|
| Instagramアカウントの所持 | あり・新規作成・連動なし |
| Facebookアカウントの所持 | あり・なし |
| Googleビジネスアカウントの所持 | あり・なし |
| オーナー権限 | わかる・不明 |
| 業態 | 店舗型・出張型・店舗型＆出張型 |
| GBP権限 | お客様所持・新規取得・所持者不明 |
| GBPインバウンド多言語対策 | あり・なし |
| 言語選択 | 英語・中国語・韓国語・スペイン語・フランス語・ドイツ語・イタリア語・ポルトガル語・オランダ語・ロシア語・アラビア語 |
| GMB連絡が取りやすい時間帯 | いつでも・9-12・12-15・15-18・午前中・午後・その他 |
| バリアフリー / Wi-Fi | 有無 / なし・無料・有料 |

---

## 5. 掲示板のメール転送ルーティング（P4-14 の重要入力）

各掲示板の**ステータスごとにメール送付先が定義**されている。これは通知の実仕様。

### 5-1. ステータス→送付先

| 掲示板 | ステータス | 送付先 |
|---|---|---|
| 後確 | 営業部対応依頼 / 後確NG / 後確OK | 販売店にメール |
| 後確 | 再申請 | `ecotech-order@if-n.co.jp` |
| 制作対応 | FT確認依頼 / 再申請 | `bridgeplus_order@ftgroup.co.jp` |
| 制作対応 | 営業部対応依頼 | 販売店にメール |
| 検収コール | 検収コールNG / 検収コールOK | 販売店にメール |
| 検収コール | 再申請 | `bridgeplus_order@ftgroup.co.jp` |

### 5-2. アフター掲示板は構造が異なる（問い合わせ管理に近い）

アフター掲示板は単純なステータスではなく、**分類＋対応者ルーティング**を持つ。

| 項目 | 選択肢 |
|---|---|
| ステータス（必須） | 未対応・対応中・対応済・完了 |
| カテゴリ1（必須） | 至急・本日中・翌営業日対応・対応不要 |
| カテゴリ2（必須） | 問合せ・クレーム・消セン |
| カテゴリ3（必須） | 契約・請求・解約・システム・運用・その他 |
| 受電窓口 | FT管理部・FT運用部・FT債権回収・代理店・なし |
| 初回対応者 / 次回対応者（必須） | 営業担当 / FT管理（契約・請求）/ FT運用（システム）/ FTコール（確認・検収）/ なし |

**次回対応者による送付先ルーティング**：

| 次回対応者 | 送付先 |
|---|---|
| 営業担当 | 販売店にメール |
| FT管理（契約・請求） | `ftg_billing_management@ftgroup.co.jp` / `support7000@ftcom.co.jp` |
| FT運用（システム） | `bridgeplus_kanri@ftgroup.co.jp` |
| FTコール（確認・検収） | `ecotech-order@if-n.co.jp` |

> **設計への示唆**：
> - P4-14 の通知ルーティングは「掲示板種別 × ステータス（or 対応者）→ 宛先」のマスタで表現する。
>   現行の転送先設定がそのまま**通知テンプレート/受信グループ**（実装済みの `recipient_groups`）に対応。
> - **アフター掲示板は問い合わせ管理に近い**（カテゴリ・受電窓口・対応者）。
>   `inquiries` 機能への統合を検討（Q-C 掲示板の実装方針と連動）。
> - 送付先に**外部委託先アドレス**（`nouhin-admin@sup-ss.co.jp` = アシスト系、`if-n.co.jp`）が
>   含まれる。委託先との連携（G-7）に関わる。
>
> **brige-crm 実装状況（R4 実装済み・決定 D-11）**:
> - §5-1 の「掲示板×ステータス→送付先」= `InquiryRecipientRoute`（`inquiry_recipient_routes`: category × status_code → `recipient_group_id`、
>   管理UI `Admin::InquiryRecipientRoutesController`）＋ `RecipientGroup` / `RecipientGroupMember`（polymorphic: Agency / SalesRepresentative /
>   Customer / User）。「販売店にメール」は `RecipientResolver.resolve_from_order`（案件→代理店・営業担当者・顧客の自動解決）が担う。
> - §5-2 のアフター掲示板は `Inquiry`（category = アフター問合せ）の `after_urgency`（カテゴリ1）/ `after_type`（カテゴリ2）/
>   `after_area`（カテゴリ3）/ `reception_channel`（受電窓口）/ `first_responder_name` / `next_responder_name` として統合済み。
>   「次回対応者→送付先」ルーティングは `InquiryRecipientRoute` の status_code ベースで表現するか、対応者ベースの経路を追加するかは
>   **未確定**（現状は status_code のみ）。
> - **✅ 2026-08-20: 本表（§5-1/§5-2）の転送先を `RecipientGroup` / `InquiryRecipientRoute` へ投入する初期データを作成済み**（`app/services/inquiry_recipient_seeder.rb`・`db/seeds.rb` から実行）。グループ5件＋ルート4件。「販売店にメール」の行は `RecipientResolver#resolve_from_order` が全ステータスで自動送信するためルートを作らない。**転送先アドレスそのもの（共有メールアドレス13件）は投入していない**——`RecipientGroupMember` は `User` / `ProductionCompany` しか持てず、実在しないログインユーザーを作らないため、メンバー割当は運用作業（管理画面）として残してある。グループ名は暫定で業務確認待ち。

---

## 6. 反映事項

| 反映先 | 内容 | Rails版（04）での対応 |
|---|---|---|
| `development-plan.md` P2-1 | FormTemplateDefinition に `editable_by_tier` / `lock_after_status` を追加（3次元権限） | R3 `FormField` に初期実装済み |
| `development-plan.md` P2-5 | 属性1-11・各プルダウンの選択肢を OptionGroup シーダー化（本ノート §4） | R2 `OptionGroup`/`OptionValue` 実装済み。**選択肢の投入シーダーは未作成**（R6/R7） |
| `development-plan.md` P4-14 | 通知ルーティング（掲示板×ステータス→宛先）を本ノート §5 で具体化 | R4 `InquiryRecipientRoute` 実装済み。転送先13件の初期データは未投入（R7） |
| `Column.md` | 伝票番号(発送/返送)・ファクター回収備考・履歴記載枠・サイン画像の要否確認 | ファクター回収備考・履歴記載枠は実装済み。伝票番号（発送/返送）・サイン画像は未実装（R5/R7 で要否判断） |
| `business-flow-analysis.md` | 添付欄の現行バグ（合計10MB超でエラー）を改善対象として追記 | R4 Active Storage（1ファイル50MB・合計制限なし）で解消 |
| `ftlog-port.md` §5 | アフター掲示板＝問い合わせ管理への統合検討（メンション対象との関係） | 同ファイルは 2026-08-19 削除済み。統合は R4 決定 D-11（`../board-implementation-options.md`）で実施済み。メンションは 04 R6 |

---

## 7. 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-07-24 | 初版。3次元編集権限・添付バグ・属性選択肢の完全リスト・掲示板メールルーティングを整理 |
| 2026-08-19 | **Rails版改訂**（brige-crm）。`jasmin_orders`→`orders`、`FormTemplateDefinition`→`FormField`（R3 実装済み）、システムアカウントID/PASS→`order_work_details`（暗号化）、§2-1 新規フィールドの実装有無を突合（ファクター回収備考・履歴記載枠は実装済み／伝票番号・店舗メール・サイン画像は未実装）、添付・OptionGroup・掲示板ルーティングの R2/R4 実装状況を追記、`ftlog-port.md` 削除済みの差し替え |
