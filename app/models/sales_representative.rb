# 営業担当者（04 R1・Column.md §7）。受注入力画面（R3）の認証キー=代理店CD＋営業担当者CD。
# T-2是正済み: sales_rep_code はLaravel現行が既にグローバルユニークなのでそのまま踏襲する
# （代理店内ユニークではなくシステム全体でユニーク）。
# == Schema Information
#
# Table name: sales_representatives
#
#  id                 :uuid             not null, primary key
#  email              :string
#  is_active          :boolean          default(TRUE), not null
#  name               :string           not null
#  pdf_address_detail :string
#  pdf_city           :string
#  pdf_fax_number     :string
#  pdf_phone_number   :string
#  pdf_postal_code    :string
#  pdf_prefecture     :string
#  pdf_store_name     :string
#  pdf_town           :string
#  sales_rep_code     :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  agency_id          :uuid             not null
#  created_by_id      :uuid
#  updated_by_id      :uuid
#
# Indexes
#
#  index_sales_representatives_on_agency_id       (agency_id)
#  index_sales_representatives_on_email           (email)
#  index_sales_representatives_on_is_active       (is_active)
#  index_sales_representatives_on_sales_rep_code  (sales_rep_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class SalesRepresentative < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :agency

  validates :sales_rep_code, presence: true, uniqueness: true, length: { maximum: 50 } # T-2: グローバルユニーク
  validates :name, presence: true, length: { maximum: 100 }
  validates :email, length: { maximum: 255 }

  scope :active, -> { where(is_active: true) }
end
