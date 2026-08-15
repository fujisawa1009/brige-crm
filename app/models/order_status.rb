# 案件ステータスマスタ（04 R2タスク4・Column.md §10 status備考）。
# code は Order#status に格納される値（例: "0:受注" "10:作業進行中"）。
# == Schema Information
#
# Table name: order_statuses
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
#  index_order_statuses_on_code                      (code) UNIQUE
#  index_order_statuses_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class OrderStatus < ApplicationRecord
  include SystemManagedStatus

  # 受注直後の既定ステータス（Order#assign_default_status が参照）。
  CODE_ORDERED = "0:受注"

  has_many :orders, foreign_key: :status, primary_key: :code, inverse_of: false
end
