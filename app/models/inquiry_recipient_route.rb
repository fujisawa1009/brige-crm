# 種別×ステータス→宛先グループのルーティングマスタ（04 R4タスク2・決定D-11。
# db/migrate/20260815160004参照）。RecipientResolver.route_for(category:, status_code:)がここを引く。
# == Schema Information
#
# Table name: inquiry_recipient_routes
#
#  id                 :uuid             not null, primary key
#  category           :string           not null
#  status_code        :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  created_by_id      :uuid
#  recipient_group_id :uuid             not null
#  updated_by_id      :uuid
#
# Indexes
#
#  index_inquiry_recipient_routes_on_category_status        (category,status_code)
#  index_inquiry_recipient_routes_on_category_status_group  (category,status_code,recipient_group_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (recipient_group_id => recipient_groups.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class InquiryRecipientRoute < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :recipient_group

  validates :category, presence: true, inclusion: { in: -> { Inquiry::CATEGORIES } }
  validates :status_code, presence: true
  validates :recipient_group_id, uniqueness: { scope: %i[category status_code] }
  validate :status_code_must_exist_for_category

  scope :for_category_and_status, ->(category, status_code) { where(category: category, status_code: status_code) }

  private

  def status_code_must_exist_for_category
    return if category.blank? || status_code.blank?
    return if InquiryStatus.exists?(category: category, code: status_code)

    errors.add(:status_code, "はinquiry_statusesに存在しないコードです（#{category}/#{status_code}）")
  end
end
