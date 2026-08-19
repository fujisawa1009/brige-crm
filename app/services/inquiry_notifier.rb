# 問い合わせメッセージ作成時のアプリ内通知（04 R4タスク4）。
#
# InquiryMessageRecipientはAgency/SalesRepresentative/Customer/User/RecipientGroupの5型を許すが
# （app/models/inquiry_message_recipient.rb）、アプリ内通知（SystemNotification）を表示できるのは
# ログインアカウントを持つUser（管理画面）とCustomer（マイページ）だけ。Agency/SalesRepresentativeは
# 現行スコープ（R4）にログインダッシュボードを持たないため通知対象から外し、RecipientGroupは
# メンバー（User/ProductionCompany）へ展開する（ProductionCompanyもログインアカウントを持たないため
# 実質Userのみに通知される）。
class InquiryNotifier
  def self.notify_message_created(inquiry_message)
    new(inquiry_message).notify
  end

  def initialize(inquiry_message)
    @inquiry_message = inquiry_message
  end

  def notify
    notification_type = first_message? ? SystemNotification::TYPE_INQUIRY_CREATED : SystemNotification::TYPE_INQUIRY_REPLIED
    payload = {
      inquiry_id:      inquiry.id,
      inquiry_number:  inquiry.inquiry_number,
      title:           inquiry.title,
      inquiry_message_id: inquiry_message.id
    }

    each_notifiable_recipient do |recipient|
      # R6-1: 個人ごとの通知設定（E4/E9/E10案件関連の通知）でアプリ内通知をOFFにしている場合は
      # 作らない（判定はNotificationSettingGateに集約。メール側の同種判定はInquiryMessageMailJob）。
      next unless NotificationSettingGate.app_enabled?(
        recipient_type: recipient.class.name, recipient_id: recipient.id,
        event_type: NotificationEventType::INQUIRY_CASE_RELATED
      )

      SystemNotification.create!(recipient: recipient, notification_type: notification_type, data: payload)
    end
  end

  private

  attr_reader :inquiry_message

  def inquiry = inquiry_message.inquiry

  def first_message?
    inquiry.inquiry_messages.order(:created_at).first.id == inquiry_message.id
  end

  def each_notifiable_recipient(&block)
    inquiry_message.inquiry_message_recipients.find_each do |recipient_row|
      case recipient_row.recipient_type
      when "User", "Customer"
        block.call(recipient_row.recipient)
      when "RecipientGroup"
        recipient_row.recipient.recipient_group_members.where(recipient_type: "User").find_each do |member|
          block.call(member.recipient)
        end
      end
    end
  end
end
