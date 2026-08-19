# 一斉通知の送信結果（04 R4タスク3。db/migrate/20260815160010参照）。
# == Schema Information
#
# Table name: notification_recipients
#
#  id              :uuid             not null, primary key
#  email           :string
#  error_message   :text
#  recipient_type  :string           not null
#  sent_at         :datetime
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  notification_id :uuid             not null
#  recipient_id    :uuid             not null
#
# Indexes
#
#  idx_on_recipient_type_recipient_id_7b525e48ed     (recipient_type,recipient_id)
#  index_notification_recipients_on_notification_id  (notification_id)
#
# Foreign Keys
#
#  fk_rails_...  (notification_id => notifications.id) ON DELETE => cascade
#
class NotificationRecipient < ApplicationRecord
  STATUS_PENDING = "pending"
  STATUS_SENT    = "sent"
  STATUS_FAILED  = "failed"

  belongs_to :notification
  belongs_to :recipient, polymorphic: true

  validates :recipient_type, presence: true
  validates :status, presence: true, inclusion: { in: [ STATUS_PENDING, STATUS_SENT, STATUS_FAILED ] }

  def mark_sent!
    update!(status: STATUS_SENT, sent_at: Time.current)
  end

  def mark_failed!(message)
    update!(status: STATUS_FAILED, error_message: message)
  end
end
