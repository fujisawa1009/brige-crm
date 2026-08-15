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
  SYSTEM_ADMIN_ONLY_CONTROLLERS = %w[
    admin/role_management
    admin/permission_management
    admin/login_histories
    admin/ip_allowlist_entries
  ].freeze

  # 全ロール共通の「自分の状態」系コントローラー（ftlog踏襲。ログイン後に必ず到達できる画面）。
  SELF_SERVICE_CONTROLLERS = %w[
    admin/dashboard
  ].freeze

  # 04 R1: 組織・アカウント5コントローラ。実務運用者（内部スタッフ）は全操作可。
  # AgencyScoped（app/policies/concerns/agency_scoped.rb）のPundit判定と対になる方針:
  #   - create（new含む）は原則スタッフのみ。組織構造・契約条件・アカウント発行は内部運用の管轄とし、
  #     代理店側からの新規作成パラメータによる権限昇格の経路を作らない（04 R1本文には明記が無いため、
  #     CEO不在下のCTO判断。理由はcommit message参照）。
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

  def assign_default_permissions(roles)
    admin_permissions = SystemPermission.enabled.admin

    # admin(super_admin) は SystemPermissionChecker のバイパスで全許可されるため個別割当は不要。
    non_admin_role_names = SystemRole::BUILT_IN_ROLE_NAMES - [ "admin" ]
    non_admin_role_names.each do |name|
      grant(roles[name], admin_permissions.where(controller: SELF_SERVICE_CONTROLLERS).pluck(:id))
    end

    grant(roles["実務運用者"], admin_permissions.where(controller: R1_ORGANIZATION_CONTROLLERS).pluck(:id))

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
