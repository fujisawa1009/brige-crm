# users.agency_id/agency_group_id FKがON DELETE => nullifyのため、staffがAgency/AgencyGroupを
# destroyすると配下Userのagency_id/agency_group_idがDBレベルでNULL化されていた。
# AgencyScoped#staff_scope?（agency_id・agency_group_idが両方nil=staff=全件アクセス可）と組み合わさると、
# 削除の瞬間に配下ユーザーが意図せず全件アクセス権限へ昇格する権限昇格の脆弱性になっていた。
# モデル側のhas_many :users（Agency/AgencyGroup）をdependent: :restrict_with_errorへ変更したのに合わせ、
# DBレベルのFKもON DELETE RESTRICTへ揃える（sales_representatives等の他関連と同じ防御パターン）。
class ChangeUsersAgencyForeignKeysToRestrict < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :users, :agencies
    remove_foreign_key :users, :agency_groups

    add_foreign_key :users, :agencies, on_delete: :restrict
    add_foreign_key :users, :agency_groups, on_delete: :restrict
  end
end
