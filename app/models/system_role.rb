# エンドポイントRBAC・ロール（03§3）。ftlogのSystemRoleから acts_as_tenant（organization_id）・
# organizationスコープのユニーク制約・portalフラグ（顧客ポータル用ロール）を除去した単一テナント版。
# mypage/formセクションはロール割当を使わない運用（03§3「ロール割当の編集対象はadmin sectionのみ」）
# のため、SystemRoleは実質adminセクション専用として扱う。
class SystemRole < ApplicationRecord
  include TracksUser
  include Auditable

  # 組み込み4ロールの雛形（04 R0-5・Laravel現行の名称をそのまま維持=変更禁止指定）。
  # RoleSeeder がこの定義からロールを作成する。name は種別を判定するための固定キー。
  BUILT_IN_ROLE_ATTRIBUTES = {
    "admin" => {
      display_name: "admin",
      description:  "システム管理者。ユーザー管理・ロール管理・権限管理・監査ログ・IP許可リストを含む全機能を利用できます。",
      super_admin:  true
    },
    "実務運用者" => {
      display_name: "実務運用者",
      description:  "社内の実務担当者。日常業務のCRUD操作を行えます。"
    },
    "代理店グループ用" => {
      display_name: "代理店グループ用",
      description:  "代理店グループ管理者。配下代理店のデータを横断して参照・操作できます（Punditスコープで制御。R1で実装）。"
    },
    "代理店用" => {
      display_name: "代理店用",
      description:  "代理店担当者。自代理店のデータのみ参照・操作できます（Punditスコープで制御。R1で実装）。"
    }
  }.freeze

  BUILT_IN_ROLE_NAMES = BUILT_IN_ROLE_ATTRIBUTES.keys.freeze

  has_many :user_system_roles, dependent: :destroy
  has_many :users, through: :user_system_roles
  has_many :system_role_permissions, dependent: :destroy
  has_many :system_permissions, through: :system_role_permissions

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: true
  validates :display_name, length: { maximum: 50 }
  validates :description,  length: { maximum: 255 }
  validate :built_in_roles_must_be_system
  validate :system_role_name_cannot_change, if: :persisted?

  before_destroy :prevent_system_role_destroy

  def built_in?
    BUILT_IN_ROLE_NAMES.include?(name)
  end

  def label
    display_name.presence || name
  end

  # 種別判定は name 文字列ではなくフラグを参照する（ftlog踏襲。リネームで種別を取り違えない）。
  def admin?
    super_admin?
  end

  private

  def built_in_roles_must_be_system
    return unless built_in? && !system?

    errors.add(:system, "must be true for built-in roles")
  end

  def system_role_name_cannot_change
    return unless system? && will_save_change_to_name?

    errors.add(:name, "cannot be changed for system roles")
  end

  def prevent_system_role_destroy
    return unless system?

    errors.add(:base, "System roles cannot be destroyed")
    throw :abort
  end
end
