class SystemRolePermission < ApplicationRecord
  belongs_to :system_role
  belongs_to :system_permission

  validates :system_role_id, uniqueness: { scope: :system_permission_id }
end
