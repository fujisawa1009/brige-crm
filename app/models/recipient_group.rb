# 宛先グループ（04 R4タスク3。Laravel RecipientGroup.php移植。db/migrate/20260815160001参照）。
# == Schema Information
#
# Table name: recipient_groups
#
#  id            :uuid             not null, primary key
#  description   :text
#  is_active     :boolean          default(TRUE), not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_recipient_groups_on_is_active  (is_active)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class RecipientGroup < ApplicationRecord
  include TracksUser
  include Auditable

  has_many :recipient_group_members, dependent: :destroy
  has_many :inquiry_recipient_routes, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 255 }

  scope :active, -> { where(is_active: true) }
end
