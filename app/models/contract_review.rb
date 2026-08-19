# 契約ワークフロー状態機械（Order#transition_contract_to!）の遷移履歴・差戻し内容（04 R5-1）。
# コンプライアンス証跡としてUPDATEで上書きせず追記型で持つ（disclosure_checksと同じ思想。
# contract-confirmation-docs.md §3-1）。監査ログ(AuditLog)はuser_id NOT NULLのため、
# 将来顧客本人による遷移が発生する場合に備えてこちらで完結させる（payment_transaction_logsと同じ
# 設計判断。payment-integration.md §4-5）。
# == Schema Information
#
# Table name: contract_reviews
#
#  id              :uuid             not null, primary key
#  comment         :text
#  event           :string           not null
#  from_status     :string
#  performed_at    :datetime         not null
#  reason          :text
#  returned_to     :string
#  target_fields   :jsonb            not null
#  to_status       :string           not null
#  created_at      :datetime         not null
#  order_id        :uuid             not null
#  performed_by_id :uuid
#
# Indexes
#
#  index_contract_reviews_on_order_id                   (order_id)
#  index_contract_reviews_on_order_id_and_performed_at  (order_id,performed_at)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#  fk_rails_...  (performed_by_id => users.id)
#
class ContractReview < ApplicationRecord
  belongs_to :order
  belongs_to :performed_by, class_name: "User", optional: true

  validates :event, presence: true
  validates :to_status, presence: true
  validates :performed_at, presence: true
end
