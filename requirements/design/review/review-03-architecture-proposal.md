# レビュー: 03-rails-architecture-proposal.md 徹底洗い直し

- レビュー担当: CTO（`agents/cto-agent.md` ペルソナ）
- 対象: `projects/brige-crm/requirements/design/03-rails-architecture-proposal.md`（v2・§8決定録A〜F CEO決定済み 2026-08-14）
- 参照した一次資料:
  - `projects/brige-crm/requirements/design/01-laravel-current-analysis.md`
  - `projects/brige-crm/requirements/design/02-ftlog-architecture-analysis.md`
  - `projects/brige-crm/requirements/design/04-rails-implementation-plan.md`
  - `projects/boilerplate-vue-env/laravel/requirements/development-plan.md`
  - `projects/boilerplate-vue-env/laravel/requirements/design/payment-integration.md`
  - `projects/boilerplate-vue-env/laravel/requirements/design/pii-handling-rules.md`
  - `projects/boilerplate-vue-env/laravel/requirements/design/Inquiry-email.md`
  - `projects/boilerplate-vue-env/laravel/requirements/design/Column.md`
  - `projects/boilerplate-vue-env/laravel/requirements/development-plan-review-20260726.md`
- スタンス: 実装着手（R0）前の最後の防波堤。テンションを保つため、良い所は良いと書くが、疑わしい箇所は根拠を積んで指摘する。

---

## ✅ 確認済み（01/02/Laravel要件と整合していた主張）

1. **DB=PostgreSQL・UUID・pg_bigm（決定A）** — 02 §1の技術スタック記述（PostgreSQL/pg_bigm/UUID）とそのまま整合。01 §1「現Laravel=MySQL 8」との差分も03 §2の備考「移行はどのみちETL」で正しく吸収されている。

2. **決済状態機械の7状態** — 03 §5「決済（PaymentTransaction）は状態機械・ログテーブル含め忠実移植」の状態集合（`pending/authorized/captured/failed/unknown/canceled/refunded`）は、01 §2-6の記述および `payment-integration.md` §4-4 の記述と**完全に一致**。unknown≠failed／二重課金防止（冪等キー）の設計原則も `payment-integration.md` §4-2・§4-4 と整合。

3. **Q-19（メールOTP一本化）・Q-22（監査ログ5年保存）** — development-plan.md §8で共に✅決定済み（Q-19「メールOTPに一本化・TOTP廃止」、Q-22「D-6: 全体延長・5年」）であることを確認。03 §2「Q-19を最初から満たす」「保存5年（Q-22）」の記述は実際のステータスと一致している。

4. **T-2/T-3の是正方針とその根拠** — 03 §5「T-2: sales_rep_codeをグローバルユニークに」「T-3: contract_condition_idは受注側に持たせる」は、`Column.md` L361/L379（sales_rep_codeのグローバルユニーク制約が明記済み）・L444/L458（contract_condition_idがjasmin_orders側のFKとして設計済み）と一致。**Column.md（設計の正）は既に是正済みの姿で書かれており**、現行コードとの乖離が負債T-2/T-3という位置づけも `development-plan-review-20260726.md` §1-3 と符合する。03の記述は正確。

5. **単一テナント方針の大枠** — 03 §1-4「ftlogのマルチテナント機構 acts_as_tenant は移植しない」は、02 §7「brige-crmが単一テナントなら不要。SystemRoleのテナントスコープ・RoleSeederを単純化できる」という02自身の結論と整合している（詳細レベルの懸念は下記➕不足を参照）。

6. **決定Fとデータ移行スコープ** — 03 §8決定録F「別フェーズ切り出し」および備考「legacy-research/ETL設計は流用。スキーマ設計時にマッピング整合を常時確認」は、01 §8-16「新スキーマはlegacy-research/11-order-field-mapping.mdと整合させること」、development-plan.md Q-C（掲示板統合・42万件は参照アーカイブ、✅決定済み）と矛盾なく対応している。04 §R7もこの方針を踏襲。

---

## ⚠️ 矛盾・誤り（01/02や実要件と食い違う記述。根拠を明示）

### 1. 【最重要】決定D「JasminCustomer→Customer」が Laravel 側の明示的なリネーム設計と正面衝突している

`projects/boilerplate-vue-env/laravel/requirements/design/Inquiry-email.md` L21-61「⚠️ モデル名変更が必要：JasminCustomer について」には、以下が明記されている：

- **現状の問題**: `JasminCustomer` は「Customer」を名乗るが実態は**法人・契約単位のエンティティ**であり、ログイン情報（email/password）を一切持たない。
- **役割の整理表**（L41-44）: `JasminCustomer`（現在）＝契約エンティティ・ログインなし／`Customer`（新規・今後作成）＝マイページにログインする**顧客アカウント**・ログインあり。**この2つは意図的に別モデルとして分離する設計**。
- TODO（L59-61）: 「リネーム後のモデル名・テーブル名を確定する」（候補: `Contract` / `JasminContract` / `ServiceContract` / `CustomerContract`）。**`Customer` という名前は新規作成予定のログインエンティティのために予約されている**。

一方、03 §5 決定D（§8決定録Dも同一）は「`jasmin_` プレフィックスを外す（`JasminCustomer`→`Customer`, `JasminOrder`→`Order` 等）」としており、**契約エンティティである JasminCustomer にそのまま `Customer` という名前を割り当てている**。さらに03 §4「顧客マイページ（Customer）| Devise 別スコープ」は、この同じ `Customer` にマイページログイン機能を持たせる設計になっている。

これは Laravel 側が「役割の曖昧さ」として明示的に問題視し分離を指示した conflation（契約エンティティとログインエンティティの同一視）を、**Rails側で単純な機械的リネームによりそのまま再生産する**ことを意味する。development-plan.md の負債T-4「`JasminCustomer` のモデル名／役割の曖昧さ（Inquiry-emailリネームTODO）」は、03では**解決されておらず、むしろ固定化されるリスクがある**。

02 §4「User は STI（`type`: Staff / Customer）」の ftlog 流用イメージとも整合させるなら、`Customer` は「ログインする顧客アカウント」に予約し、契約エンティティ側には別名（`Contract` 系候補、または `CustomerAccount` と対で `ContractSubject` 等）を充てるべき。**R2着手前にモデル名の再設計が必要**。

### 2. §5「T-5相当の残骸（nestedset/organizations画面）は持ち込まない」の T番号ラベルが誤り

development-plan.md L94「T-5 | `composer.json` の name が starter-kit のまま | 実害小」が実際のT-5であり、nestedset/organizations画面とは**無関係**。01自身も §8-8（nestedsetの記述）にT番号を付けておらず、01のどこにも「nestedset＝T-5」という対応は存在しない。03の「T-5相当」という表現は存在しない負債番号との対応付けであり、根拠のない引用。実害は小さいが、決定録・負債管理の正確性という観点で修正すべき（正しくは「Laravel現行の未使用残骸（nestedset/organizations画面。T番号なし）」等の表現にする）。

### 3. §4認証設計が development-plan.md の CEO決定 Q-23（D-5）「二要素認証を全画面必須」を反映していない

development-plan.md §8「~~Q-23~~ | 二要素認証を必須にする対象 | ✅ CEO決定 2026-07-26（D-5）: **全画面必須**（マイページ・受注入力含む）」と明記されている。しかし03 §4の認証設計表は：

| 系統 | 方式 |
|---|---|
| 管理画面（User） | Devise + **ftlog式メールOTP** + rack-attack |
| 顧客マイページ（Customer） | Devise 別スコープ（OTP要件の記載なし） |
| 受注入力（営業担当者） | 独自セッション認証（OTP要件の記載なし） |

管理画面にのみ明示的にOTPが書かれ、マイページ・受注入力にはOTP要件が記載されていない。01自身もQ-23を明示的に引用していない（01が言及するのはQ-19のみ）ため、**01からの転記漏れがそのまま03に伝播した可能性が高い**。CEO決定である以上、03 §4はマイページ・受注入力にも「メールOTP等での二要素認証を要件化する」旨を明記すべき（特に受注入力は独自セッションのため、OTPをどう組み込むかは設計課題として新規に発生する）。

---

## ➕ 不足・要具体化（決定はされているが実装可能なレベルまで詳細化されていない箇所）

### 1. §3「section段階での構造的遮断」の実装メカニズムが未規定（特に form セクション）

03 §3の設計意図①は「権限チェックの最初に『このユーザ種別が入れる sectionか』を判定し…構造的に遮断する」としているが、02 §2-2/§2-3が示す ftlog の実装は：

```
before_action :authenticate_user!            # Devise 認証（scope別）
before_action :authorize_system_permission!  # SystemPermissionChecker#allowed?

def allowed?
  ...
  if user.staff?      then staff_allowed?     # user.staff?/customer? は STI 判定
  elsif user.customer? then customer_allowed?
  else false
end
```

つまり実際の「誤配線防止」は **section フィールドそのものへのランタイム比較ではなく**、①Deviseの認証スコープ（admin=Userのcurrent_user、mypage=Customerのcurrent_customer）でそもそも別ゲストとして到達不能にする仕組み、②STI型（`user.staff?`/`user.customer?`）で分岐するロジック、の組み合わせで成立している。

ここで**受注入力（form）系統はDevise/STI対象外**（03 §4に明記の通り `SalesRepresentative は Devise 対象外`）であるため、`SystemPermissionChecker#allowed?` の `user.staff?`/`user.customer?` 分岐に**そもそも乗らない**。以下のいずれかを明確に設計する必要があるが、03には記載がない：

- (a) checkerに第3の分岐（例: `user.sales_rep?`）を追加し、formセクションもRBACカタログの管理下に置く
- (b) 02の `skip_system_permission_authorization?`（devise/招待系の除外パターン）と同様に、form名前空間のコントローラは `authorize_system_permission!` を完全にスキップし、独自の `FormAuth` 相当ミドルウェアのみで保護する

(b)の場合、formセクションは「3区分の一つ」というより「RBACの管理対象外＝別建ての独立系統」になり、§3が謳う「section段階の構造的遮断」という説明はform方向には適用されない（保護はRBACではなく独自セッションミドルウェア側の責務になる）。どちらを採るかで実装・テスト設計が変わるため、**R0着手前に明記が必要**。

なお、タスクで懸念された「営業担当者セッションがadminルートに到達するケース」自体は、Devise `authenticate_user!` が `current_user` 不在で弾く（form独自セッションはDeviseのwardenに乗らない）ため、実質的には**section機構ではなくDevise認証スコープの分離で守られる**可能性が高い。03の説明は「section」を守りの主役として書いているが、実際の一次防御はDeviseスコープ分離である旨を正確に書き分けたほうがよい。

### 2. 単一テナント簡素化（決定Eの前提）は02の記述範囲を超えて断定している

02 §7「移植時の注意」は `SystemPermission`=グローバル/`SystemRole`=テナント別の非対称構造について「単一テナントなら SystemRole のスコープを外し、`OrganizationRoleSeeder` を `RoleSeeder` に単純化」とのみ述べており、**具体的に列挙されているのは `SystemRole`・`SystemRolePermission`（実質は間接）・`UserSystemRole` のみ**（02 §2-1）。

02 §5「業務系」には `notifications` / `audit_logs` / `login_histories` / `ip_allowlist_entries` 等が列挙されているが、これらが `organization_id` を持つか・`acts_as_tenant` の `require_tenant` に依存するバリデーションを持つかは**02の調査範囲外（未確認）**。03 §1-4／04ではこれを「移植しない」と一律の前提で書いているが、02自体がこれらのテーブルの `acts_as_tenant` 依存を網羅的に確認した記述ではない。R0のDocker/認可移植着手時に、**ftlog実コードを対象に `acts_as_tenant`・`organization_id` の依存箇所を横断grepし、除去可否を個別に確認する作業**を明示タスクとして立てるべき（04のR0チェックリストに現状この項目がない）。

### 3. §6 PII暗号化対象の記述が曖昧（「WorkDetailのSNS認証情報等」）

`pii-handling-rules.md` §1「分類B: 外部認証情報」は「SNSアカウントのID/パスワード（Instagram・Facebook・Google）・**システムアカウントID/PASS**・**請求パスワード**・現行システム（ジャスミン等）のログイン情報」と定義しており、`legacy-research/11` §4（01 §2-2で参照）によれば instagram_id/pass・facebook_id/pass・google_account_id/pass・system_account_id/pass など複数フィールドが対象で、件数（63/166、66/67等）まで判明している。

03 §5「WorkDetail の SNS認証情報等は `ActiveRecord::Encryption` で暗号化保存」の「等」は、システムアカウント認証情報・請求パスワードを含むのか、また対象テーブルが `OrderWorkDetail` のみか `JasminOrder`（信販9カラム含む）本体にも及ぶのかが読み取れない。R2着手前に `Column.md`／`legacy-research/11` §4 に基づき対象カラムを列挙すべき。

### 4. 決済「mark/confirm分離」の出典がコード解析であり、設計文書（payment-integration.md）には明文化されていない

01 §2-6の「`mark*`（同期応答起点）と `confirm*`（サーバ間確定起点）を分離」という記述は、**Laravelの実装コード（`PaymentTransactionStatus` Enum）を解析した結果**であり、`payment-integration.md` 自体にはこの命名・メソッド分離パターンは明文化されていない（同ドキュメント§4-3「戻り値を信用しない」・§4-4「不確定を状態として持つ」が思想としては近いが、mark/confirmという用語・API面は出てこない）。

01冒頭は「Rails移植では実装コードよりこの要件群（requirements/）が正」と明言しており、実装コードは参考情報という位置づけである。03 §5「忠実移植」の対象にこの mark/confirm 分離が含まれることは適切だが、**出典が「コード解析（01 §2-6）」であり設計書側には存在しないことを明記しないと**、実装者が `payment-integration.md` のみを読んで移植した場合にこのパターンが漏れるリスクがある。03に一言「mark/confirmの分離はLaravel実装コード由来（01 §2-6）。移植時は実コードも直接確認すること」を足すべき。

### 5. フォーム動的定義（P2拡張後仕様）の実装フェーズが03単体では読み取れない

03 §5「フォーム定義は P2拡張後仕様（target_table/target_column＋3次元編集権限）を初期スキーマに採用」自体は妥当な決定だが、これが**どのフェーズ（R0〜R7のどれ）で実現されるか**03には記載がない。04 §R3で「FormTemplate / FormStep / FormField — P2拡張後仕様…を初期実装」と明記されているため実質的な欠落ではないが、03 §9「参照」に04への逆リンクの言及がなく、03単体を読んだ読者はフェーズが分からない。軽微だが、一覧性のため03側にも「→R3」等の一言を添えるとよい。

---

## ❓ 要CEO確認・未決事項（曖昧なまま実装に進むとリスクがある論点）

### 1. Q-D（SNS認証情報の暗号化 vs 非保持）が未決のまま、03は「決定済み」トーンで書かれている

development-plan.md §8では Q-D は依然「未確認」のまま。`pii-handling-rules.md` §5は明確に「**Q-D が確定するまで、分類Bのカラムは移行 load 対象から保留**とし、ETL準備工程では他フィールドと分離した中間ファイルに隔離しておく」という立場を取っている（つまり「運ぶか運ばないか自体が先に決まるべき」というスタンス）。

03 §5は「暗号化保存を既定にする（Q-D への先回り提案）」と書いており、括弧内で「提案」と留保してはいるものの、文全体としては既定事項であるかのようなトーンになっている。04 §リスク5では「PII/認証情報の暗号化方針（Q-D）はR2着手前に確定が必要」と正しくゲート化されているが、**03自体の書きぶりと04のリスク認識との間に温度差**がある。R2着手前に、CEOへ「Q-D自体（そもそも新システムへ運ぶか）」の決定を仰ぐ必要がある。運ばない判断になった場合、03 §5の暗号化提案自体が不要になる（マッピング設計が変わる）ため、**Q-D確定を03のR2着手条件として明記**すべき。

### 2. T-4（JasminCustomerのリネーム）とモデル命名決定Dの衝突（上記⚠️1）はCEO再確認が必要

上記の通り、現在の決定D（`jasmin_` プレフィックス除去でJasminCustomer→Customer）はLaravel側の意図的なリネーム設計と衝突する。これは「プレフィックスを外す」という機械的操作では済まない論点であり、`Customer` の割当先（契約エンティティ側かログインエンティティ側か）をCEOに再確認し、決定録D自体の修正が必要。

### 3. §3 formセクションのRBAC統合方式（上記➕1）は実装着手前に確定が必要

「formセクションをSystemPermissionCheckerの管理下に置くか、完全に独立させるか」は認可アーキテクチャの根幹に関わるため、R0着手前にCTO/開発担当が具体設計を詰め、CEOまたは意思決定者に確認を仰ぐべき。

### 4. 決定E備考「ftlog複製はテナント機構・issue系の削除コストが高いため不採用」は定性判断であり、見積もりの裏付けが01/02に無い

01/02のどちらにも複製コストの定量的な記述は無く、03独自の判断根拠。方向性として不自然ではないが、CEOへ説明する際は「コスト試算済みの結論ではなく定性的判断である」ことを共有した方が誠実（優先度は低い）。

---

## まとめ

- 上記の指摘件数: **⚠️矛盾・誤り 3件**（うち1件は最重要＝モデル命名決定Dの衝突）、**➕不足・要具体化 5件**、**❓要CEO確認 4件**。
- 最優先で潰すべきは⚠️1（決定D vs Inquiry-email.mdのリネーム設計の衝突）。次点で⚠️3（Q-23全画面2FAの欠落）と➕1（formセクションのRBAC統合方式未規定）。この3点はR0/R2着手前に解消しないと手戻りが大きい。
