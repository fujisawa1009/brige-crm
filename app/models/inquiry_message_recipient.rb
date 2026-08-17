# 問い合わせメッセージの宛先展開（04 R4タスク1。Laravel InquiryMessageRecipient移植。
# db/migrate/20260815160007参照）。recipient_typeはRailsのクラス名文字列（polymorphic規約どおり）で、
# Agency/SalesRepresentative/Customer/User/RecipientGroupの5種のみを許可する
# （RecipientResolver.resolve_from_order / .route_for の戻り値と対応）。
# == Schema Information
#
# Table name: inquiry_message_recipients
#
#  id                  :uuid             not null, primary key
#  recipient_type      :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  inquiry_message_id  :uuid             not null
#  recipient_id        :uuid             not null
#
# Indexes
#
#  index_inquiry_message_recipients_on_message_id  (inquiry_message_id)
#  index_inquiry_message_recipients_on_recipient_type_and_recipient_id  (recipient_type,recipient_id)
#
# Foreign Keys
#
#  fk_rails_...  (inquiry_message_id => inquiry_messages.id) ON DELETE => cascade
#
class InquiryMessageRecipient < ApplicationRecord
  RECIPIENT_TYPES = %w[Agency SalesRepresentative Customer User RecipientGroup].freeze

  belongs_to :inquiry_message, inverse_of: :inquiry_message_recipients
  belongs_to :recipient, polymorphic: true

  validates :recipient_type, presence: true, inclusion: { in: RECIPIENT_TYPES }
end
