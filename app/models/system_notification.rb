# アプリ内通知（04 R4タスク4。Laravel SystemNotification.php移植。db/migrate/20260815160011参照）。
# recipient（受信者。User or Customer）へSolid Cable（ActionCable）でリアルタイム配信し、30日で
# 自動prune（config/recurring.yml参照）する。MassPrunable相当はRails標準機能に無いため、
# 自前でprune_expired!を実装しSolid Queueのrecurringタスクから呼ぶ（04 R4本文の方針どおり）。
# == Schema Information
#
# Table name: system_notifications
#
#  id                :uuid             not null, primary key
#  data              :jsonb            not null
#  expires_at        :datetime         not null
#  notification_type :string           not null
#  read_at           :datetime
#  recipient_type    :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  recipient_id      :uuid             not null
#
# Indexes
#
#  index_system_notifications_on_recipient_and_read_at  (recipient_type,recipient_id,read_at)
#  index_system_notifications_on_expires_at             (expires_at)
#
class SystemNotification < ApplicationRecord
  TYPE_INQUIRY_CREATED        = "inquiry_created"
  TYPE_INQUIRY_REPLIED        = "inquiry_replied"
  TYPE_APPLICATION_COMPLETED  = "application_completed"
  TYPE_NOTIFICATION_SENT      = "notification_sent"

  TYPES = [
    TYPE_INQUIRY_CREATED, TYPE_INQUIRY_REPLIED, TYPE_APPLICATION_COMPLETED, TYPE_NOTIFICATION_SENT
  ].freeze

  RETENTION = 30.days

  belongs_to :recipient, polymorphic: true

  before_validation :assign_default_expiry, on: :create

  validates :notification_type, presence: true, inclusion: { in: TYPES }
  validates :expires_at, presence: true

  after_create_commit :broadcast_to_recipient

  scope :unread, -> { where(read_at: nil) }
  scope :not_expired, -> { where("expires_at > ?", Time.current) }
  scope :for_recipient, ->(recipient) { where(recipient: recipient) }

  # SystemNotificationsChannelが購読するストリーム名（recipientの型×idで一意）。
  # チャネル側（app/channels/system_notifications_channel.rb）と文字列を1箇所で共有する。
  def self.stream_name_for(recipient_type:, recipient_id:)
    "system_notifications:#{recipient_type}:#{recipient_id}"
  end

  def mark_as_read!
    update!(read_at: Time.current) if read_at.nil?
  end

  # 30日経過分の削除（Laravel MassPrunable相当。config/recurring.ymlの日次ジョブから呼ぶ）。
  def self.prune_expired!
    where("expires_at < ?", Time.current).delete_all
  end

  # after_create_commitのフック本体を公開メソッドにしておく（channel specから直接呼び出して
  # broadcastを検証できるようにするため。トランザクショナルフィクスチャ配下ではafter_commitが
  # 発火しないテストの制約を避ける狙い。app/channels/system_notifications_channel_spec.rb参照）。
  def broadcast_to_recipient
    ActionCable.server.broadcast(
      self.class.stream_name_for(recipient_type: recipient_type, recipient_id: recipient_id),
      {
        id:                id,
        notification_type: notification_type,
        data:               data,
        created_at:         created_at
      }
    )
  end

  private

  def assign_default_expiry
    self.expires_at ||= RETENTION.from_now
  end
end
