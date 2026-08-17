# 通知テンプレート（04 R4タスク3。Laravel NotificationTemplate.php移植。db/migrate/20260815160008参照）。
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
class NotificationTemplate < ApplicationRecord
  include TracksUser
  include Auditable

  TYPE_NOTIFICATION = "notification"
  TYPE_INQUIRY       = "inquiry"
  TYPE_COMMON        = "common"

  TEMPLATE_TYPES = {
    TYPE_NOTIFICATION => "通知用",
    TYPE_INQUIRY       => "問い合わせ用",
    TYPE_COMMON        => "共通"
  }.freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :template_type, presence: true, inclusion: { in: TEMPLATE_TYPES.keys }
end
