# 営業資料マスタ（04 R2タスク6・Laravel移行元 SalesMaterial.php）。カテゴリ6種。
# == Schema Information
#
# Table name: sales_materials
#
#  id                 :uuid             not null, primary key
#  category           :string(50)
#  description        :text
#  file_path          :string(500)      not null
#  file_size          :bigint           not null
#  is_published       :boolean          default(FALSE), not null
#  mime_type          :string(100)      not null
#  original_file_name :string(255)      not null
#  sort_order         :integer          default(0), not null
#  title              :string(255)      not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  created_by_id      :uuid
#  updated_by_id      :uuid
#
# Indexes
#
#  index_sales_materials_on_category      (category)
#  index_sales_materials_on_is_published  (is_published)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class SalesMaterial < ApplicationRecord
  include TracksUser
  include Auditable

  CATEGORIES = %w[提案書 会社案内 価格表 製品カタログ マニュアル その他].freeze

  validates :title, presence: true, length: { maximum: 255 }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :file_path, presence: true, length: { maximum: 500 }
  validates :original_file_name, presence: true, length: { maximum: 255 }
  validates :file_size, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :mime_type, presence: true, length: { maximum: 100 }

  scope :published, -> { where(is_published: true) }
  scope :ordered, -> { order(:sort_order) }
end
