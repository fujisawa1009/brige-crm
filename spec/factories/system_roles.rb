# == Schema Information
#
# Table name: system_roles
#
#  id            :uuid             not null, primary key
#  description   :text
#  display_name  :string
#  name          :string           not null
#  position      :integer
#  super_admin   :boolean          default(FALSE), not null
#  system        :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_system_roles_on_name      (name) UNIQUE
#  index_system_roles_on_position  (position)
#  index_system_roles_on_system    (system)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :system_role do
    sequence(:name) { |n| "role-#{n}" }
    display_name { name }
    super_admin { false }
    system { false }
  end
end
