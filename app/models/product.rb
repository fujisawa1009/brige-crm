# 商材マスタ（04 R2タスク3・Laravel移行元 Product.php）。code は一意のシステムキー。
# == Schema Information
#
# Table name: products
#
#  id            :uuid             not null, primary key
#  code          :string(20)       not null
#  description   :text
#  is_active     :boolean          default(TRUE), not null
#  name          :string(100)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_products_on_code       (code) UNIQUE
#  index_products_on_is_active  (is_active)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class Product < ApplicationRecord
  include TracksUser
  include Auditable

  has_many :plans, dependent: :restrict_with_error
  has_many :product_initial_fees, dependent: :destroy
  has_many :product_options, dependent: :destroy
  has_many :orders, through: :plans
  # 販売許可（04 R1で先送りされた中間テーブルをR2で実装）。
  has_many :agency_products, dependent: :destroy
  has_many :agencies, through: :agency_products
  has_many :agency_group_products, dependent: :destroy
  has_many :agency_groups, through: :agency_group_products
  # 04 R3: 申込フォーム定義（03§5「Product 1─1 FormTemplate」）。
  has_one :form_template, dependent: :destroy
  has_many :applications, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, uniqueness: true, length: { maximum: 20 }

  scope :active, -> { where(is_active: true) }

  # 指定の代理店（直接許可 or 所属代理店グループへの許可）が販売可能な商材か判定する
  # （04 R2タスク8「販売許可の有無で見える商材が変わる設計にする場合はここで反映」）。
  # サブクエリのOR条件のためjoins+.orではなくwhere文字列で組む（joins先が異なるテーブル同士の
  # .orはRailsの構造適合チェックに引っかかりやすいため、シンプルなIN句2本の方が読みやすく安全）。
  def self.sellable_by(agency)
    return none if agency.blank?

    where(
      "id IN (SELECT product_id FROM agency_products WHERE agency_id = :agency_id) " \
      "OR id IN (SELECT product_id FROM agency_group_products WHERE agency_group_id = :agency_group_id)",
      agency_id: agency.id, agency_group_id: agency.agency_group_id
    )
  end
end
