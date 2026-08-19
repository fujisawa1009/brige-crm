# 一斉通知（04 R4）。既定は代理店宛の下書き。
# == Schema Information
#
# Table name: notifications
#
#  id                       :uuid             not null, primary key
#  body                     :text
#  failed_count             :integer          default(0), not null
#  filter_params            :jsonb            not null
#  scheduled_at             :datetime
#  sent_at                  :datetime
#  status                   :string           default("draft"), not null
#  subject                  :string
#  success_count            :integer          default(0), not null
#  target_type              :string           not null
#  title                    :string           not null
#  total_count              :integer          default(0), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  created_by_id            :uuid
#  notification_template_id :uuid
#  updated_by_id            :uuid
#
# Indexes
#
#  index_notifications_on_notification_template_id  (notification_template_id)
#  index_notifications_on_scheduled_at              (scheduled_at)
#  index_notifications_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (notification_template_id => notification_templates.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
FactoryBot.define do
  factory :notification do
    sequence(:title) { |n| "通知#{n}" }
    target_type { Notification::TARGET_AGENCY }
    status { Notification::STATUS_DRAFT }
    subject { "通知件名" }
    body { "通知本文" }
  end
end
