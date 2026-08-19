# 宛先グループメンバー（04 R4）。recipient は User または ProductionCompany（polymorphic）。
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
FactoryBot.define do
  factory :recipient_group_member do
    association :recipient_group
    association :recipient, factory: :user
  end
end
