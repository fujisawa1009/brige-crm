# 問い合わせ（04 R4）。status は category から Inquiry#assign_default_status が既定値を割り当てるが、
# その既定コードが inquiry_statuses に存在する必要があるため、このfactoryを使うspecは
# :seed_status_catalog タグ（StatusSeeder が inquiry_statuses も投入する）を付けること。
# == Schema Information
#
# Table name: inquiries
#
#  id                     :uuid             not null, primary key
#  after_area             :string
#  after_type             :string
#  after_urgency          :string
#  category               :string           not null
#  first_responder_name   :string
#  inquiry_number         :string           not null
#  is_visible_to_agent    :boolean          default(TRUE), not null
#  is_visible_to_customer :boolean          default(TRUE), not null
#  next_responder_name    :string
#  reception_channel      :string
#  status                 :string           not null
#  title                  :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  created_by_id          :uuid
#  order_id               :uuid             not null
#  updated_by_id          :uuid
#
# Indexes
#
#  index_inquiries_on_category_and_status  (category,status)
#  index_inquiries_on_inquiry_number       (inquiry_number) UNIQUE
#  index_inquiries_on_order_id             (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (order_id => orders.id) ON DELETE => restrict
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :inquiry do
    association :order
    category { Inquiry::CATEGORY_AFTER }
    sequence(:title) { |n| "問い合わせ#{n}" }
  end
end
