# 契約ステータスマスタ（04 R5-1・basic-design.md §9〜§12「契約ワークフロー状態機械」）。
# code は Order#contract_status に格納される値。不備チェック→差戻し→確認コール→契約確定の
# 各節に散在していたステータスを1本化したもの（案件ステータス/申込ステータスと並ぶ第3の語。
# status-naming-analysis.md Q-B）。遷移表は Order::CONTRACT_STATUS_TRANSITIONS 参照。
# == Schema Information
#
# Table name: contract_statuses
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
#  index_contract_statuses_on_code                      (code) UNIQUE
#  index_contract_statuses_on_is_active_and_sort_order  (is_active,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class ContractStatus < ApplicationRecord
  include SystemManagedStatus

  # 契約ワークフロー未着手（orders.contract_status が blank）から最初に入る状態。
  CODE_PENDING_CHECK = "pending_check"
  # 不備チェックで問題ありと判断され差戻された直後。
  CODE_RETURNED = "returned"
  # 差戻し理由・対象項目を登録し、代理店営業担当者/顧客が修正中。
  CODE_BEING_CORRECTED = "being_corrected"
  # 修正待ち（相手からの再申請待ち）。
  CODE_REAPPLICATION_PENDING = "reapplication_pending"
  # 再申請を受けて不備チェックの再実施待ち。
  CODE_RECHECK_PENDING = "recheck_pending"
  # 不備チェック通過後、確認コールの架電待ち。
  CODE_CONFIRM_CALL_PENDING = "confirm_call_pending"
  # 確認コール完了。
  CODE_CONFIRM_CALL_DONE = "confirm_call_done"
  # 確認コールの結果が不十分で再確認が必要。
  CODE_NEEDS_RECONFIRMATION = "needs_reconfirmation"
  # 確認コール完了後、契約確定の最終判断待ち。
  CODE_CONTRACT_CONFIRMATION_PENDING = "contract_confirmation_pending"
  # 契約確定（終端状態）。
  CODE_CONTRACTED = "contracted"

  has_many :orders, foreign_key: :contract_status, primary_key: :code, inverse_of: false
end
