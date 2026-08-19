# 種別×ステータス→宛先グループのルーティング（04 R4）。status_code は inquiry_statuses に
# 存在する必要があるため :seed_status_catalog タグ前提。既定はアフター問合せの「未対応」。
# == Schema Information
#
# Table name: inquiry_recipient_routes
#
#  id                 :uuid             not null, primary key
#  category           :string           not null
#  status_code        :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  created_by_id      :uuid
#  recipient_group_id :uuid             not null
#  updated_by_id      :uuid
#
# Indexes
#
#  index_inquiry_recipient_routes_on_category_status        (category,status_code)
#  index_inquiry_recipient_routes_on_category_status_group  (category,status_code,recipient_group_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (recipient_group_id => recipient_groups.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :inquiry_recipient_route do
    association :recipient_group
    category { Inquiry::CATEGORY_AFTER }
    status_code { "未対応" }
  end
end
