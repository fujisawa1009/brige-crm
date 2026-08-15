# 代理店グループ（04 R1・Column.md §1）。傘下の agencies を束ねる基点。
# group_code はUI上「ログインID」として表示するが、実際の認証は users.email（グループ担当者は
# agency_group_id のみ設定されたUser）で行う（Column.md §1備考踏襲）。
# == Schema Information
#
# Table name: agency_groups
#
#  id                       :uuid             not null, primary key
#  bridge_plan_display_type :string
#  contact_email            :string
#  csv_download_visible     :boolean
#  group_code               :string           not null
#  name                     :string           not null
#  service_type             :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  created_by_id            :uuid
#  updated_by_id            :uuid
#
# Indexes
#
#  index_agency_groups_on_group_code  (group_code) UNIQUE
#  index_agency_groups_on_name        (name)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class AgencyGroup < ApplicationRecord
  include TracksUser
  include Auditable

  SERVICE_TYPES = %w[Bridge BridgePlus].freeze

  has_many :agencies, dependent: :restrict_with_error
  # グループ担当者アカウント（agency_group_id のみ設定されたUser。Column.md §1「グループアカウント」）。
  has_many :users, dependent: :nullify

  validates :name, presence: true, length: { maximum: 255 }
  validates :service_type, presence: true, inclusion: { in: SERVICE_TYPES }
  validates :group_code, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :contact_email, length: { maximum: 255 }
  validates :bridge_plan_display_type, inclusion: { in: %w[ハイブリッド プラン全表示] }, allow_nil: true
end
