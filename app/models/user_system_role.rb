# 単一テナントのため、ftlog原本にあった「ユーザーとロールの組織一致バリデーション」は不要
# （SystemRoleに organization_id が無いため越境自体が起こりえない）。
# == Schema Information
#
# Table name: user_system_roles
#
#  id             :uuid             not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  system_role_id :uuid             not null
#  user_id        :uuid             not null
#
# Indexes
#
#  index_user_system_roles_on_system_role_id              (system_role_id)
#  index_user_system_roles_on_user_id_and_system_role_id  (user_id,system_role_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (system_role_id => system_roles.id)
#  fk_rails_...  (user_id => users.id)
#
class UserSystemRole < ApplicationRecord
  belongs_to :user
  belongs_to :system_role

  validates :user_id, uniqueness: { scope: :system_role_id }
end
