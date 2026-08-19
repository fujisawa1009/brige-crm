# 重説チェックの実施記録ヘッダ（04 R5-13・contract-confirmation-docs.md §3-1）。
# Q-3決定により案件（Order）単位。UPDATEで上書きせず追記型（コンプライアンス証跡）。
# performed_by はポリモーフィック（実装対象はQ-2決定によりCustomer一択。将来拡張余地として残す）。
# == Schema Information
#
# Table name: disclosure_checks
#
#  id                     :uuid             not null, primary key
#  method                 :string           default("web_check"), not null
#  performed_at           :datetime         not null
#  performed_by_type      :string           not null
#  result                 :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  disclosure_item_set_id :uuid             not null
#  order_id               :uuid             not null
#  performed_by_id        :uuid             not null
#
# Indexes
#
#  idx_on_performed_by_type_performed_by_id_6fec7c8419  (performed_by_type,performed_by_id)
#  index_disclosure_checks_on_order_id                  (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (disclosure_item_set_id => disclosure_item_sets.id)
#  fk_rails_...  (order_id => orders.id)
#
class DisclosureCheck < ApplicationRecord
  METHOD_WEB_CHECK = "web_check"
  METHODS = [ METHOD_WEB_CHECK ].freeze

  RESULT_COMPLETED = "completed"
  RESULT_INCOMPLETE = "incomplete"
  RESULTS = [ RESULT_COMPLETED, RESULT_INCOMPLETE ].freeze

  belongs_to :order
  belongs_to :disclosure_item_set
  belongs_to :performed_by, polymorphic: true

  has_many :disclosure_check_items, dependent: :destroy
  accepts_nested_attributes_for :disclosure_check_items

  validates :method, presence: true, inclusion: { in: METHODS }
  validates :result, presence: true, inclusion: { in: RESULTS }
  validates :performed_at, presence: true
  validate :required_items_must_be_checked_when_completed

  private

  # Q-4決定: 重説チェックは申込フォーム送信のブロック条件（チェックしない限り送信できない）。
  # result=completedと申告しているのに必須項目が未チェックのレコードを許可すると証跡が矛盾するため、
  # モデル側でも二重に担保する。
  def required_items_must_be_checked_when_completed
    return unless result == RESULT_COMPLETED

    required_item_ids = disclosure_item_set&.disclosure_items&.where(is_required: true)&.pluck(:id) || []
    checked_item_ids = disclosure_check_items.reject(&:marked_for_destruction?)
                                              .select(&:checked?).map(&:disclosure_item_id)

    return if (required_item_ids - checked_item_ids).empty?

    errors.add(:base, "必須項目が未チェックのままresult=completedにはできません")
  end
end
