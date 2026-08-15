# エンドポイントRBAC・レイヤー1（03§3）。ルート署名を権限単位にしたグローバルなカタログ。
# ftlogのSystemPermissionをそのまま移植（グローバル設計自体はテナント有無に依存しないため無改造）。
# == Schema Information
#
# Table name: system_permissions
#
#  id          :uuid             not null, primary key
#  action      :string           not null
#  controller  :string           not null
#  enabled     :boolean          default(TRUE), not null
#  http_method :string           not null
#  name        :string
#  path        :string           not null
#  section     :string           default("admin"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_system_permissions_on_enabled          (enabled)
#  index_system_permissions_on_route_signature  (controller,action,http_method,path) UNIQUE
#  index_system_permissions_on_section          (section)
#
class SystemPermission < ApplicationRecord
  has_many :system_role_permissions, dependent: :destroy
  has_many :system_roles, through: :system_role_permissions

  # admin / form / mypage の3区分（決定C。03§3）
  SECTIONS = %w[admin form mypage].freeze

  scope :enabled, -> { where(enabled: true) }
  scope :admin,   -> { where(section: "admin") }
  scope :form,    -> { where(section: "form") }
  scope :mypage,  -> { where(section: "mypage") }

  validates :controller, :action, :http_method, :path, presence: true
  validates :section, inclusion: { in: SECTIONS }
  validates :controller, uniqueness: { scope: [ :action, :http_method, :path ] }

  def route_signature
    [ controller, action, http_method, path ]
  end

  def display_name
    name.presence || "#{controller}##{action}"
  end
end
