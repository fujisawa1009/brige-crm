# 既定ロール×権限マトリクスの単一入口（04 R0-5）。ftlogのOrganizationRoleSeederから
# 組織スコープ（acts_as_tenant）を除去し単純化したもの（02の移植方針どおり）。
# db/seeds.rb と起動後の運用（rake経由の再実行）の両方から呼べる冪等な実装。
#
# 前提: SystemPermission（グローバルなルート由来カタログ）が同期済みであること
# （通常は SystemPermissionSyncService.call が先行する）。
class RoleSeeder
  def self.call
    new.call
  end

  def call
    roles = create_built_in_roles
    assign_default_permissions(roles)
    roles
  end

  private

  # 組み込み4ロールを作成（冪等）。position は定義順で採番する。
  def create_built_in_roles
    SystemRole::BUILT_IN_ROLE_ATTRIBUTES.each_with_index.each_with_object({}) do |((name, attrs), index), memo|
      role = SystemRole.find_or_initialize_by(name: name)

      role.super_admin = attrs.fetch(:super_admin, false)
      role.system      = true
      role.position     = index + 1 if role.position.blank?

      if role.new_record?
        role.description  = attrs[:description]
        role.display_name = attrs[:display_name]
      end

      role.save!
      memo[name] = role
    end
  end

  # admin ロール専有のコントローラー（組織全体に効く管理機能。review-02 ➕4の教訓を継承）。
  # ip_allowlist_entries が実務運用者/代理店系ロールに開放されていると、当人が自分の接続元IPを
  # 許可リストに登録して2要素認証を回避できてしまうため、SA(admin)専有にする
  # （ftlogのSYSTEM_ADMIN_ONLY_CONTROLLERSに実在した理由をそのまま踏襲）。
  # R6-3: admin/system_settings（問い合わせ添付上限等のシステム設定）も同じ理由でadmin専有にする
  # （実務運用者以下に開放すると、添付ファイルサイズ上限を自己申告で緩められてしまうため）。
  SYSTEM_ADMIN_ONLY_CONTROLLERS = %w[
    admin/role_management
    admin/permission_management
    admin/login_histories
    admin/ip_allowlist_entries
    admin/system_settings
  ].freeze

  # 全ロール共通の「自分の状態」系コントローラー（ftlog踏襲。ログイン後に必ず到達できる画面）。
  # R6-1: admin/notification_settings（個人ごとの通知設定）も常にcurrent_user自身のみを対象とする
  # 自己サービス画面のため、他の書き込み系コントローラーのようなロール別の絞り込みを行わず全ロールへ
  # 一律付与する（admin/dashboardと同じ扱い）。
  SELF_SERVICE_CONTROLLERS = %w[
    admin/dashboard
    admin/notification_settings
  ].freeze

  # 04 R1: 組織・アカウント5コントローラ。実務運用者（内部スタッフ）は全操作可。
  # AgencyScoped（app/policies/concerns/agency_scoped.rb）のPundit判定と対になる方針:
  #   - create（new含む）は原則スタッフのみ。組織構造・契約条件・アカウント発行は内部運用の管轄とし、
  #     代理店側からの新規作成パラメータによる権限昇格の経路を作らない（04 R1本文には明記が無いため、
  #     決定者不在下のCTO判断。理由はcommit message参照）。
  #   - AgencyScopedがupdate?/destroy?をstaff_scope?のみに縮める AgencyGroup/ContractCondition は
  #     RBACレイヤーでも「そもそも到達できるアクション」を index/show に絞り、意図を明示する
  #     （Pundit側の二重防御と揃える）。
  R1_ORGANIZATION_CONTROLLERS = %w[
    admin/agency_groups
    admin/agencies
    admin/sales_representatives
    admin/contract_conditions
    admin/users
  ].freeze

  # 代理店グループ用/代理店用が参照のみ許可されるコントローラー（AgencyGroup/ContractConditionは
  # AgencyScoped側でupdate?/destroy?もstaff_scope?限定にしているため、書き込みアクションは渡さない）。
  AGENCY_SCOPED_READ_ONLY_CONTROLLERS = %w[
    admin/agency_groups
    admin/contract_conditions
  ].freeze

  # 代理店グループ用/代理店用が自スコープ内で参照・更新できるが、destroy?はstaff_scope?限定
  # （AgencyPolicy#destroy?がstaff_scope?のみに上書きされているため、RBACレイヤーでも
  # destroyアクションは渡さずPunditの制限と揃える）。
  AGENCY_SCOPED_READ_WRITE_CONTROLLERS = %w[
    admin/agencies
  ].freeze

  # 代理店グループ用/代理店用が自スコープ内で参照・更新・削除まで行えるコントローラー
  # （SalesRepresentativePolicy/UserPolicyはAgencyScoped既定のまま＝update?/destroy?ともaccessible?）。
  AGENCY_SCOPED_FULL_WRITE_CONTROLLERS = %w[
    admin/sales_representatives
    admin/users
  ].freeze

  # 04 R2: CRM中核（顧客/店舗/案件）。実務運用者は全操作可。代理店/代理店グループは
  # CustomerPolicy/OrderPolicy/StorePolicyの既定どおりcreate?がstaff_scope?限定のため、
  # RBACレイヤーでも new/create は渡さず index/show/edit/update/destroy までにする
  # （AGENCY_SCOPED_FULL_WRITE_CONTROLLERSと同じ「新規作成は内部運用限定」方針。CSVエクスポートは
  # 全ロール共通でexportアクションのみ、csv_exportsのダウンロードはindex/showを渡す）。
  R2_CRM_CONTROLLERS = %w[admin/customers admin/stores admin/orders].freeze
  # R6-7: ganttはadmin/orders専用の参照系アクション（他のR2_CRM_CONTROLLERSにはこのアクション自体が
  # 存在せずクエリが単に0件になるだけなので、配列に混ぜても admin/customers・admin/stores 側への
  # 影響はない）。index?と同じ参照権限で足りるためindex/showと同列に加える。
  R2_CRM_AGENCY_ACTIONS = %w[index show edit update destroy export gantt].freeze

  # 04 R2: 商材・ステータス・営業資料マスタ。MasterDataPolicyの既定どおり、代理店/代理店グループは
  # 参照のみ（index/show）。作成・変更は実務運用者以上に限定する（商材構成・料金・ステータス体系の
  # 自己申告変更を許すと業務ルールが崩れるため。04 R2タスク8）。
  # 04 R5-1: 契約ステータスもcustomer_statuses/order_statusesと同じ「代理店は参照のみ・変更は
  # 実務運用者以上」の状態マスタ（ContractStatusPolicyもMasterDataPolicy）。
  R2_MASTER_CONTROLLERS = %w[
    admin/products admin/plans admin/product_initial_fees admin/product_options
    admin/option_groups admin/option_values admin/customer_statuses admin/order_statuses
    admin/contract_statuses admin/production_companies admin/sales_materials
  ].freeze

  # CSVエクスポート成果物の一覧・ダウンロード。CsvExportPolicyがrequested_by本人のみに絞るため、
  # RBACレイヤーでは全ロールにindex/showを渡してよい（レコード単位の防御はPundit側で完結する）。
  CSV_EXPORT_CONTROLLERS = %w[admin/csv_exports].freeze

  # 04 R3タスク6: フォームビルダー。商材の申込フォーム定義は代理店データではなく内部運用の設定物
  # （R2_MASTER_CONTROLLERSの商材マスタ以上に「営業フローの設計」に近い）ため、参照権限すら
  # 代理店/代理店グループロールへは渡さない（実務運用者専有。admin/role_management等と同じ扱い）。
  R3_FORM_BUILDER_CONTROLLERS = %w[admin/form_templates].freeze

  # 04 R4タスク1: 問い合わせ（Inquiry）。実務運用者は起票（new/create）含めフル操作可。
  # 代理店/代理店グループは自スコープの問い合わせを参照（index/show）でき、可視な問い合わせへ
  # 返信（inquiry_messages#create）できるが、起票はできない（InquiryPolicy#create?がstaff_scope?
  # 限定＝R2_CRM_CONTROLLERSと同じ「新規作成は内部運用限定」方針。Punditの制限とRBACを揃える）。
  R4_INQUIRY_CONTROLLERS = %w[admin/inquiries].freeze
  R4_INQUIRY_MESSAGE_CONTROLLERS = %w[admin/inquiry_messages].freeze

  # 04 R4タスク3: 一斉通知・宛先グループ・通知テンプレート・問い合わせステータス/ルーティングマスタ。
  # いずれもMasterDataPolicy（書き込みはstaff_scope?限定）または内部運用ツールのため、参照権限すら
  # 代理店/代理店グループロールへは渡さず実務運用者専有にする（admin/form_templatesと同じ扱い）。
  R4_INTERNAL_CONTROLLERS = %w[
    admin/inquiry_statuses admin/inquiry_recipient_routes
    admin/recipient_groups admin/notification_templates admin/notifications
  ].freeze

  # R6-4: 問い合わせ返信テンプレート（FAQ 12カテゴリマスタ）管理。NotificationTemplate同様の
  # 内部運用マスタのため、R4_INTERNAL_CONTROLLERSと同じ扱い（実務運用者専有・代理店/代理店グループへは
  # 参照権限すら渡さない）。なお返信画面(admin/inquiries#show)でのテンプレ選択・差し込み自体は
  # InquiryTemplateを直接読むだけ（InquiryStatusと同じ参照専用データ）でこの権限を要さないため、
  # 代理店ユーザーもテンプレートを"使う"ことはできる（管理=作成/編集/削除のみが実務運用者専有）。
  R6_INQUIRY_TEMPLATE_CONTROLLERS = %w[admin/inquiry_templates].freeze

  # 04 R5-1/R5-13: 契約ワークフロー（不備チェック/確認コール/契約確定）イベント投入・重説項目セットの
  # 版管理は、basic-design.mdが一貫して「管理者が」行う工程として記述する社内工程のため、
  # R3_FORM_BUILDER_CONTROLLERSと同じく代理店/代理店グループロールへは参照権限すら渡さない
  # （OrderPolicy#transition_contract?・DisclosureItemSetPolicyもstaff_scope?限定でPundit側も一致）。
  R5_CONTRACT_WORKFLOW_CONTROLLERS = %w[admin/contract_reviews admin/disclosure_item_sets].freeze

  # R6-8: ファイル管理基盤（汎用添付）。OrderAttachmentPolicyの既定どおりcreate?はstaff_scope?限定
  # （R2_CRM_CONTROLLERSと同じ「新規作成は内部運用限定」方針）、destroy?もAgencyScoped既定を上書きして
  # staff_scope?限定にしている（契約書PDF等を代理店側の自己判断で失わせない。ポリシーのコメント参照）。
  # 代理店/代理店グループへはdownload（閲覧・ダウンロード）のみ渡す。
  R6_8_ORDER_ATTACHMENT_CONTROLLERS = %w[admin/order_attachments].freeze

  def assign_default_permissions(roles)
    admin_permissions = SystemPermission.enabled.admin

    # admin(super_admin) は SystemPermissionChecker のバイパスで全許可されるため個別割当は不要。
    non_admin_role_names = SystemRole::BUILT_IN_ROLE_NAMES - [ "admin" ]
    non_admin_role_names.each do |name|
      grant(roles[name], admin_permissions.where(controller: SELF_SERVICE_CONTROLLERS).pluck(:id))
    end

    grant(roles["実務運用者"], admin_permissions.where(controller: R1_ORGANIZATION_CONTROLLERS).pluck(:id))
    # 04 R2: 実務運用者はCRM中核・マスタ系ともフル操作可（new/createを含む全アクション）。
    grant(roles["実務運用者"], admin_permissions.where(controller: R2_CRM_CONTROLLERS).pluck(:id))
    grant(roles["実務運用者"], admin_permissions.where(controller: R2_MASTER_CONTROLLERS).pluck(:id))
    grant(roles["実務運用者"], admin_permissions.where(controller: CSV_EXPORT_CONTROLLERS).pluck(:id))
    grant(roles["実務運用者"], admin_permissions.where(controller: R3_FORM_BUILDER_CONTROLLERS).pluck(:id))
    # 04 R4: 問い合わせは起票含めフル、通知・宛先グループ・テンプレート・ルーティングマスタは内部運用専有。
    grant(roles["実務運用者"], admin_permissions.where(controller: R4_INQUIRY_CONTROLLERS).pluck(:id))
    grant(roles["実務運用者"], admin_permissions.where(controller: R4_INQUIRY_MESSAGE_CONTROLLERS).pluck(:id))
    grant(roles["実務運用者"], admin_permissions.where(controller: R4_INTERNAL_CONTROLLERS).pluck(:id))
    # R6-4: 問い合わせ返信テンプレート管理も内部運用マスタのため実務運用者専有。
    grant(roles["実務運用者"], admin_permissions.where(controller: R6_INQUIRY_TEMPLATE_CONTROLLERS).pluck(:id))
    # 04 R5: 契約ワークフロー・重説項目セットは内部工程のため実務運用者専有。
    grant(roles["実務運用者"], admin_permissions.where(controller: R5_CONTRACT_WORKFLOW_CONTROLLERS).pluck(:id))
    # R6-8: ファイル管理基盤。実務運用者はアップロード・削除・ダウンロードすべて可（Pundit側の
    # OrderAttachmentPolicyでも代理店スコープの範囲チェックが別途かかる）。
    grant(roles["実務運用者"], admin_permissions.where(controller: R6_8_ORDER_ATTACHMENT_CONTROLLERS).pluck(:id))

    %w[代理店グループ用 代理店用].each do |name|
      grant(
        roles[name],
        admin_permissions.where(controller: AGENCY_SCOPED_READ_ONLY_CONTROLLERS, action: %w[index show]).pluck(:id)
      )
      grant(
        roles[name],
        admin_permissions.where(controller: AGENCY_SCOPED_READ_WRITE_CONTROLLERS, action: %w[index show edit update])
                          .pluck(:id)
      )
      grant(
        roles[name],
        admin_permissions.where(controller: AGENCY_SCOPED_FULL_WRITE_CONTROLLERS,
                                 action: %w[index show edit update destroy]).pluck(:id)
      )
      # 04 R2: CRM中核は new/create を除く（CustomerPolicy/OrderPolicy/StorePolicyのcreate?が
      # staff_scope?限定のため、RBACレイヤーでも到達できるアクションを揃える）。
      grant(
        roles[name],
        admin_permissions.where(controller: R2_CRM_CONTROLLERS, action: R2_CRM_AGENCY_ACTIONS).pluck(:id)
      )
      # マスタ系は参照のみ（MasterDataPolicyのcreate?/update?/destroy?がstaff_scope?限定のため）。
      grant(
        roles[name],
        admin_permissions.where(controller: R2_MASTER_CONTROLLERS, action: %w[index show]).pluck(:id)
      )
      grant(
        roles[name],
        admin_permissions.where(controller: CSV_EXPORT_CONTROLLERS, action: %w[index show]).pluck(:id)
      )
      # 04 R4: 自スコープの問い合わせ参照（index/show）＋可視な問い合わせへの返信（inquiry_messages#create）。
      # 起票（inquiries#new/create）はInquiryPolicy#create?がstaff_scope?限定のため渡さない。
      grant(
        roles[name],
        admin_permissions.where(controller: R4_INQUIRY_CONTROLLERS, action: %w[index show]).pluck(:id)
      )
      grant(
        roles[name],
        admin_permissions.where(controller: R4_INQUIRY_MESSAGE_CONTROLLERS, action: %w[create]).pluck(:id)
      )
      # R6-8: 自スコープOrderの添付ファイルはダウンロードのみ（アップロード・削除は実務運用者専有。
      # OrderAttachmentPolicy#create?/#destroy?のstaff_scope?限定とRBACレイヤーを揃える）。
      grant(
        roles[name],
        admin_permissions.where(controller: R6_8_ORDER_ATTACHMENT_CONTROLLERS, action: %w[download]).pluck(:id)
      )
    end
  end

  # 追加のみ（剥奪しない）。マトリクス縮小の反映は別途「破壊的再同期」タスクで行う（ftlog踏襲。
  # R0では未実装。運用が必要になった時点でrake taskとして追加する）。
  def grant(role, permission_ids)
    ids      = Array(permission_ids).flatten.uniq
    existing = SystemRolePermission.where(system_role: role, system_permission_id: ids).pluck(:system_permission_id)
    (ids - existing).each do |perm_id|
      SystemRolePermission.create!(system_role_id: role.id, system_permission_id: perm_id)
    end
  end
end
