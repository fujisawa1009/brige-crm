# == Schema Information
#
# Table name: system_role_permissions
#
#  id                   :uuid             not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  system_permission_id :uuid             not null
#  system_role_id       :uuid             not null
#
# Indexes
#
#  index_system_role_permissions_on_role_and_permission   (system_role_id,system_permission_id) UNIQUE
#  index_system_role_permissions_on_system_permission_id  (system_permission_id)
#
# Foreign Keys
#
#  fk_rails_...  (system_permission_id => system_permissions.id)
#  fk_rails_...  (system_role_id => system_roles.id)
#
class SystemRolePermission < ApplicationRecord
  belongs_to :system_role
  belongs_to :system_permission

  validates :system_role_id, uniqueness: { scope: :system_permission_id }
end
