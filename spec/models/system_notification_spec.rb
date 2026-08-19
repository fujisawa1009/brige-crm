require "rails_helper"

# 04 R4タスク4: アプリ内通知。既定有効期限の付与・既読化・期限切れpruneを検証する。
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
#  index_system_notifications_on_expires_at             (expires_at)
#  index_system_notifications_on_recipient_and_read_at  (recipient_type,recipient_id,read_at)
#
RSpec.describe SystemNotification, type: :model do
  it "作成時にexpires_at（30日後）を自動付与する" do
    notification = create(:system_notification)
    expect(notification.expires_at).to be_within(1.minute).of(SystemNotification::RETENTION.from_now)
  end

  it "notification_typeは既定の集合のみ許可する" do
    notification = build(:system_notification, notification_type: "unknown")
    expect(notification).not_to be_valid
  end

  it "mark_as_read!でread_atが入り、二重呼び出しでは変わらない" do
    notification = create(:system_notification)
    notification.mark_as_read!
    first = notification.read_at
    expect(first).to be_present

    notification.mark_as_read!
    expect(notification.read_at).to eq(first)
  end

  it "prune_expired!は期限切れのみ削除する" do
    live = create(:system_notification)
    expired = create(:system_notification)
    expired.update_column(:expires_at, 1.day.ago)

    described_class.prune_expired!

    expect(described_class.exists?(live.id)).to be(true)
    expect(described_class.exists?(expired.id)).to be(false)
  end

  it "unread/not_expiredスコープが機能する" do
    unread = create(:system_notification)
    read = create(:system_notification)
    read.mark_as_read!

    expect(described_class.unread).to include(unread)
    expect(described_class.unread).not_to include(read)
  end
end
