# 問い合わせ返信テンプレート（R6-4）。
# == Schema Information
#
# Table name: inquiry_templates
#
#  id            :uuid             not null, primary key
#  body          :text             not null
#  category      :string           not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_inquiry_templates_on_category  (category)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :inquiry_template do
    category { InquiryTemplate::CATEGORIES.first }
    sequence(:name) { |n| "テンプレート#{n}" }
    body { "お世話になっております。%{customer_name}様よりお問い合わせいただいた%{order_number}の件について回答いたします。" }
  end
end
