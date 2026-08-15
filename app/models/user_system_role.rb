# 単一テナントのため、ftlog原本にあった「ユーザーとロールの組織一致バリデーション」は不要
# （SystemRoleに organization_id が無いため越境自体が起こりえない）。
class UserSystemRole < ApplicationRecord
  belongs_to :user
  belongs_to :system_role

  validates :user_id, uniqueness: { scope: :system_role_id }
end
