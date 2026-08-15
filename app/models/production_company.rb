# 制作会社マスタ（04 R2タスク6・Laravel移行元 ProductionCompany.php）。
# inquiry_messages との紐付け（inquiry_message_production_companies）はR4（問い合わせ）で追加する。
# == Schema Information
#
# Table name: production_companies
#
#  id            :uuid             not null, primary key
#  contact_name  :string(50)
#  email         :string(255)
#  is_active     :boolean          default(TRUE), not null
#  name          :string(100)      not null
#  notes         :text
#  phone         :string(20)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_production_companies_on_is_active  (is_active)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class ProductionCompany < ApplicationRecord
  include TracksUser
  include Auditable

  validates :name, presence: true, length: { maximum: 100 }
  validates :contact_name, length: { maximum: 50 }
  validates :email, length: { maximum: 255 }
  validates :phone, length: { maximum: 20 }

  scope :active, -> { where(is_active: true) }
end
