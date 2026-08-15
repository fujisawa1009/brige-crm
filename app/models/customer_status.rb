# 顧客ステータスマスタ（04 R2タスク4・Column.md §8 status備考）。
# code は Customer#status に格納される値。is_system=true の行（CODE_APPLIED/CODE_WITHDRAWN）は
# コード側から意味づけて参照するため削除・code変更を禁止する（SystemManagedStatus参照）。
# == Schema Information
#
# Table name: customer_statuses
#
#  id            :uuid             not null, primary key
#  code          :string           not null
#  is_active     :boolean          default(TRUE), not null
#  is_system     :boolean          default(FALSE), not null
#  label         :string           not null
#  sort_order    :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_customer_statuses_on_code                      (code) UNIQUE
#  index_customer_statuses_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class CustomerStatus < ApplicationRecord
  include SystemManagedStatus

  # ワークフロー開始時点の既定ステータス（Customer#assign_default_status が参照）。
  CODE_APPLIED = "applied"
  # 退会済み（Laravel JasminCustomer::CODE_WITHDRAWN 踏襲。Customer.activeスコープの除外条件）。
  CODE_WITHDRAWN = "withdrawn"

  has_many :customers, foreign_key: :status, primary_key: :code, inverse_of: false
end
