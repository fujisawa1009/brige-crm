# 問い合わせメッセージ（04 R4タスク1。Laravel InquiryMessage.php移植。db/migrate/20260815160006参照）。
# 添付はActive Storage（has_many_attached）。Laravel現行の「合計10MB超でエラー」バグ（05反映事項）を
# 踏まえ、点検は個々のファイルサイズ／件数のみで合計サイズは制限しない（Active Storageのdirect
# uploadと相性が悪い合計判定は避け、個々のガードに留める）。
# 上限値はR6-3でSystemSetting（システム設定画面）のDB管理へ切り出した（旧 MAX_ATTACHMENTS /
# MAX_ATTACHMENT_SIZE class定数は撤去。既定値5件/50MBはSystemSettingのカラムdefaultへ移設済みで
# 移行前後の挙動は変わらない）。
# == Schema Information
#
# Table name: inquiry_messages
#
#  id            :uuid             not null, primary key
#  body          :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  inquiry_id    :uuid             not null
#  updated_by_id :uuid
#
# Indexes
#
#  index_inquiry_messages_on_inquiry_and_created_at  (inquiry_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (inquiry_id => inquiries.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class InquiryMessage < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :inquiry, inverse_of: :inquiry_messages
  has_many :inquiry_message_recipients, dependent: :destroy, inverse_of: :inquiry_message
  has_many_attached :attachments

  validates :body, presence: true
  validate :attachments_within_limits

  # RecipientResolverが解決した宛先（[{type:, id:}, ...]）をrecipientsへ書き込む。
  # 種別×ステータスのルーティング（recipient_group）と案件経由の自動解決（agency/sales_representative/
  # customer）の両方をこの1メソッドから呼べるようにし、コントローラ側は宛先の由来を意識しなくてよい形にする。
  def assign_recipients!(resolved)
    resolved.each do |entry|
      inquiry_message_recipients.create!(recipient_type: entry.fetch(:type), recipient_id: entry.fetch(:id))
    end
  end

  private

  def attachments_within_limits
    return unless attachments.attached?

    settings = SystemSetting.current

    if attachments.count > settings.inquiry_attachment_max_count
      errors.add(:attachments, "は#{settings.inquiry_attachment_max_count}件までです")
    end

    attachments.each do |attachment|
      next unless attachment.blob&.byte_size.to_i > settings.inquiry_attachment_max_size_bytes

      errors.add(:attachments,
                  "の1ファイルあたりの上限は#{settings.inquiry_attachment_max_size_mb}MBです（#{attachment.filename}）")
    end
  end
end
