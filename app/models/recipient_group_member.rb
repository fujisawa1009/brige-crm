# 宛先グループのメンバー（04 R4タスク3。Laravel RecipientGroupMember移植。
# db/migrate/20260815160002参照）。recipientはUser or ProductionCompanyのみ（Laravel実装踏襲）。
# == Schema Information
#
# Table name: recipient_group_members
#
#  id                 :uuid             not null, primary key
#  recipient_type     :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  recipient_group_id :uuid             not null
#  recipient_id       :uuid             not null
#
# Indexes
#
#  idx_on_recipient_type_recipient_id_72cf03b455         (recipient_type,recipient_id)
#  index_recipient_group_members_on_group_and_recipient  (recipient_group_id,recipient_type,recipient_id) UNIQUE
#  index_recipient_group_members_on_group_id             (recipient_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (recipient_group_id => recipient_groups.id) ON DELETE => cascade
#
class RecipientGroupMember < ApplicationRecord
  RECIPIENT_TYPES = %w[User ProductionCompany].freeze

  belongs_to :recipient_group
  belongs_to :recipient, polymorphic: true

  validates :recipient_type, presence: true, inclusion: { in: RECIPIENT_TYPES }
  validates :recipient_id, uniqueness: { scope: %i[recipient_group_id recipient_type] }
end
