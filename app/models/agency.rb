# 代理店（04 R1・Column.md §2）。agency_group_id で代理店グループに所属する。
# agency_code はUI上「ログインID」として表示するが、実際の認証は users.email で行う。
# == Schema Information
#
# Table name: agencies
#
#  id                          :uuid             not null, primary key
#  agency_code                 :string           not null
#  contact_person              :string
#  csv_download_visible        :boolean
#  electronic_contract_enabled :boolean
#  email_1                     :string
#  email_2                     :string
#  email_3                     :string
#  email_4                     :string
#  email_5                     :string
#  name                        :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  agency_group_id             :uuid             not null
#  created_by_id               :uuid
#  updated_by_id               :uuid
#
# Indexes
#
#  index_agencies_on_agency_code      (agency_code) UNIQUE
#  index_agencies_on_agency_group_id  (agency_group_id)
#  index_agencies_on_name             (name)
#
# Foreign Keys
#
#  fk_rails_...  (agency_group_id => agency_groups.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class Agency < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :agency_group

  has_many :sales_representatives, dependent: :restrict_with_error
  has_many :contract_conditions, dependent: :destroy
  # 代理店担当者アカウント（agency_id のみ設定されたUser。Column.md §2「代理店アカウント」）。
  has_many :users, dependent: :nullify

  validates :name, presence: true, length: { maximum: 255 }
  validates :agency_code, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :contact_person, length: { maximum: 255 }
  validates :email_1, :email_2, :email_3, :email_4, :email_5, length: { maximum: 255 }

  # 現行バージョンの契約条件（effective_until = NULL）。Column.md §2 hasOne相当。
  def current_contract_condition
    contract_conditions.where(effective_until: nil).order(effective_from: :desc).first
  end
end
