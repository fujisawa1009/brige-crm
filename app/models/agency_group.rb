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
  # #Bridgeプラン表示区分。Column.md §1は「ハイブリッド/プラン全表示」の2値としていたが、
  # 本番CSV由来の実データ（Laravel AgencyGroupSeeder移植: db/seeds/agency_groups.rb）に
  # 「ストック」区分が存在するため許容する。
  BRIDGE_PLAN_DISPLAY_TYPES = %w[ハイブリッド プラン全表示 ストック].freeze

  has_many :agencies, dependent: :restrict_with_error
  # グループ担当者アカウント（agency_group_id のみ設定されたUser。Column.md §1「グループアカウント」）。
  # dependent: :nullifyだと配下Userのagency_group_idがNULL化され、AgencyScoped#staff_scope?の判定
  # （agency_id・agency_group_idが両方nil=staff）に一致してしまい、削除の瞬間に全件アクセス権限へ
  # 昇格する権限昇格バグになる。agenciesと同じくrestrict_with_errorとし、配下にUserがいる限り
  # AgencyGroup自体を削除できないようにする。
  has_many :users, dependent: :restrict_with_error
  # 販売許可（04 R2タスク3。グループ単位で許可された商材）。
  has_many :agency_group_products, dependent: :destroy
  has_many :products, through: :agency_group_products

  validates :name, presence: true, length: { maximum: 255 }
  validates :service_type, presence: true, inclusion: { in: SERVICE_TYPES }
  validates :group_code, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :contact_email, length: { maximum: 255 }
  validates :bridge_plan_display_type, inclusion: { in: BRIDGE_PLAN_DISPLAY_TYPES }, allow_nil: true
end
