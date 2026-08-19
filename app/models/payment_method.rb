# 支払方法マスタ（04 R5-5b・master-data-design-policy.md §5-3）。
# code は Order#payment_method に格納される値。D-P12①の3択分岐
# （口振=CODE_BANK_TRANSFER選択時はそのまま／クレカ=CODE_CREDIT選択時はカード登録へ／
#  おまとめ=CODE_BUNDLED選択時はカード登録画面をスキップ）で参照するため is_system=true で保護する。
# == Schema Information
#
# Table name: payment_methods
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
#  index_payment_methods_on_code                      (code) UNIQUE
#  index_payment_methods_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class PaymentMethod < ApplicationRecord
  include SystemManagedStatus

  CODE_BANK_TRANSFER = "bank_transfer"
  CODE_CREDIT = "credit"
  CODE_BUNDLED = "bundled"

  has_many :orders, foreign_key: :payment_method, primary_key: :code, inverse_of: false
end
