# 問い合わせステータスマスタ（04 R4タスク2・決定D-11。db/migrate/20260815160003参照）。
# CustomerStatus/OrderStatus（SystemManagedStatus concern）と同型だが、一意性のスコープが
# category単位である点だけが異なるため、concernをそのまま流用せずこのモデルで直接実装する
# （SystemManagedStatusは`validates :code, uniqueness: true`とグローバル一意を前提にしており、
# category内一意という要件には合わない。無理にconcernへ分岐オプションを足すより、3件のマスタの
# うち1件だけ違う制約を持つ現状は個別実装の方が素直と判断した）。
# == Schema Information
#
# Table name: inquiry_statuses
#
#  id            :uuid             not null, primary key
#  category      :string           not null
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
#  index_inquiry_statuses_on_category_active_order  (category,is_active,sort_order)
#  index_inquiry_statuses_on_category_and_code      (category,code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class InquiryStatus < ApplicationRecord
  include TracksUser
  include Auditable

  validates :category, presence: true, inclusion: { in: -> { Inquiry::CATEGORIES } }
  validates :code, presence: true, uniqueness: { scope: :category }, length: { maximum: 100 }
  validates :label, presence: true, length: { maximum: 255 }

  validate :code_cannot_change_for_system_record, if: :persisted?

  before_destroy :prevent_system_record_destroy

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order) }
  scope :for_category, ->(category) { where(category: category) }

  private

  def code_cannot_change_for_system_record
    return unless is_system? && will_save_change_to_code?

    errors.add(:code, "はシステム定義のため変更できません")
  end

  def prevent_system_record_destroy
    return unless is_system?

    errors.add(:base, "システム定義のステータスは削除できません")
    throw :abort
  end
end
