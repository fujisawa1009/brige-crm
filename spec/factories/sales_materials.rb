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
FactoryBot.define do
  factory :sales_material do
    sequence(:title) { |n| "営業資料#{n}" }
    category { "提案書" }
    file_path { "sales_materials/sample.pdf" }
    original_file_name { "sample.pdf" }
    file_size { 1024 }
    mime_type { "application/pdf" }
    is_published { true }
  end
end
