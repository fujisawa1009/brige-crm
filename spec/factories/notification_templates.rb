# 通知テンプレート（04 R4）。template_type は notification/inquiry/common のいずれか。
# == Schema Information
#
# Table name: notification_templates
#
#  id            :uuid             not null, primary key
#  body          :text
#  name          :string           not null
#  subject       :string
#  template_type :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  updated_by_id :uuid
#
# Indexes
#
#  index_notification_templates_on_template_type  (template_type)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :notification_template do
    sequence(:name) { |n| "テンプレート#{n}" }
    template_type { NotificationTemplate::TYPE_NOTIFICATION }
    subject { "テンプレート件名" }
    body { "テンプレート本文" }
  end
end
