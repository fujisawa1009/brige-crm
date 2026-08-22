# 問い合わせ宛先（RecipientGroup / InquiryRecipientRoute）の初期データ投入
# （04-rails-implementation-plan.md「リスク・注意」7 の残課題。RoleSeeder / StatusSeeder と同じ
# 冪等パターンで db/seeds.rb と運用時の再実行の両方から呼べる）。
#
# 出典（正）:
#   - legacy-research/05-legacy-spec-fields.md §5-1「掲示板×ステータス→送付先」
#   - legacy-research/05-legacy-spec-fields.md §5-2「次回対応者→送付先」
#   - notification-matrix.md E4/E9/E10・C5
#
# ⚠️ 暫定値についての注意（設計書から一意に読み取れないため、業務確認で確定させること）:
#   1. **グループ名（name）は設計書に定義が無い**。05 §5-2 の「次回対応者」選択肢の呼称
#      （営業担当 / FT管理（契約・請求） / FT運用（システム） / FTコール（確認・検収））をそのまま
#      グループ名に採用し、§5-1 にしか出てこない bridgeplus_order@ 宛は「FT受注管理」という
#      **本seederで新たに付けた暫定名**にしている。正式な部門名は業務確認で差し替える。
#   2. **グループのメンバー（RecipientGroupMember）は投入しない**。宛先の実体は外部委託先を含む
#      共有メールアドレス（下記 description 参照）で、`RecipientResolver#resolve_group_members` が
#      展開できるのは `User` / `ProductionCompany` レコードのみ。実在しない User を勝手に作ると
#      ログインアカウントが増えてしまうため、**メンバー登録は運用作業（管理画面 /admin/recipient_groups）**
#      とし、ここではグループ本体とルーティングの器だけを用意する。
#      → メンバー未登録の間、これらのグループ宛のメールは送信されない（宛先0件でスキップ）。
#         案件経由の自動宛先（代理店/営業担当者/顧客）は別経路のため影響しない。
#   3. 05 §5-1 の「販売店にメール」行は `InquiryRecipientRoute` を作らない。販売店（＝案件の代理店）
#      へは `RecipientResolver#resolve_from_order` が全ステータスで自動送信しており、ルートで
#      重ねて指定する必要がないため（notification-matrix.md E4「代理店○（全ステータス）」）。
#   4. `ecotech-order@if-n.co.jp` は §5-1（後確/再申請）と §5-2（FTコール）の両方に現れる同一アドレス。
#      ここでは §5-2 の部門名「FTコール（確認・検収）」の1グループに寄せ、後確/再申請のルートも
#      同グループを指す。**別部門として分けるべきかは業務確認事項**。
class InquiryRecipientSeeder
  def self.call
    new.call
  end

  # 宛先グループ（暫定）。description には現行の転送先アドレスを記録し、運用でメンバー
  # （User / ProductionCompany）を割り当てる際の手がかりにする。
  GROUPS = [
    {
      name: "営業担当（販売店）",
      description: "05 §5-2「次回対応者=営業担当」。送付先は個人ではなく販売店（案件の代理店）。" \
                   "代理店宛メールは RecipientResolver#resolve_from_order が自動送信するため、" \
                   "このグループはメンバー未登録のままでよい（次回対応者セレクトの選択肢として存在させる）。"
    },
    {
      name: "FT管理（契約・請求）",
      description: "05 §5-2「次回対応者=FT管理（契約・請求）」。現行転送先: " \
                   "ftg_billing_management@ftgroup.co.jp / support7000@ftcom.co.jp（メンバー未登録＝要運用設定）"
    },
    {
      name: "FT運用（システム）",
      description: "05 §5-2「次回対応者=FT運用（システム）」。現行転送先: " \
                   "bridgeplus_kanri@ftgroup.co.jp（メンバー未登録＝要運用設定）"
    },
    {
      name: "FTコール（確認・検収）",
      description: "05 §5-2「次回対応者=FTコール（確認・検収）」＋ §5-1「後確/再申請」の転送先。現行転送先: " \
                   "ecotech-order@if-n.co.jp（外部委託先。メンバー未登録＝要運用設定）"
    },
    {
      name: "FT受注管理",
      description: "05 §5-1「制作対応/FT確認依頼・再申請」「検収コール/再申請」の転送先。現行転送先: " \
                   "bridgeplus_order@ftgroup.co.jp（グループ名は本seederの暫定名。メンバー未登録＝要運用設定）"
    }
  ].freeze

  # 種別×ステータス→宛先グループ（05 §5-1。「販売店にメール」行は上記注意3のとおり作らない）。
  # status_code は StatusSeeder::INQUIRY_STATUSES に存在するコードでなければ
  # InquiryRecipientRoute のバリデーションで弾かれるため、StatusSeeder の後に実行すること。
  ROUTES = [
    { category: Inquiry::CATEGORY_POST_CONFIRM, status_code: "再申請",     group: "FTコール（確認・検収）" },
    { category: Inquiry::CATEGORY_PRODUCTION,   status_code: "FT確認依頼", group: "FT受注管理" },
    { category: Inquiry::CATEGORY_PRODUCTION,   status_code: "再申請",     group: "FT受注管理" },
    { category: Inquiry::CATEGORY_INSPECTION,   status_code: "再申請",     group: "FT受注管理" }
  ].freeze

  def call
    groups = seed_groups
    seed_routes(groups)
  end

  private

  # name をキーに冪等投入する（RecipientGroup に一意制約は無いが、運用でリネームされない限り
  # name が実質のキー。description / is_active は運用側の編集を尊重して新規作成時のみ設定する）。
  def seed_groups
    GROUPS.each_with_object({}) do |attrs, acc|
      group = RecipientGroup.find_or_initialize_by(name: attrs[:name])
      group.description = attrs[:description] if group.new_record?
      group.save!
      acc[attrs[:name]] = group
    end
  end

  def seed_routes(groups)
    ROUTES.each do |attrs|
      group = groups.fetch(attrs[:group])
      InquiryRecipientRoute.find_or_create_by!(
        category: attrs[:category],
        status_code: attrs[:status_code],
        recipient_group: group
      )
    end
  end
end
