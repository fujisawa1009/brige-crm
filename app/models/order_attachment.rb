# R6-8 ファイル管理基盤（04-implementation-plan.md R6-8）。Orderに紐づく汎用の添付ファイル1件を
# 表す（1レコード=1ファイル。ftlogのFolderViewer相当を「1ファイル=1可視性フラグ」に簡略化した設計）。
# 将来R5-11（契約書PDF）・重説チェック・手書き署名の添付先として使えることを想定した汎用基盤であり、
# file_type は分類タグ程度に留め、中身が契約書かどうかをこのモデルが検証・強制することはしない
# （契約書PDF生成ロジックそのものはR5-11のスコープで範囲外）。
#
# 決済状態機械・契約ワークフロー状態機械（Order#transition_contract_to!等）には一切関与しない。
# == Schema Information
#
# Table name: order_attachments
#
#  id                     :uuid             not null, primary key
#  file_type              :string(50)
#  is_visible_to_customer :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  created_by_id          :uuid
#  order_id               :uuid             not null
#  updated_by_id          :uuid
#
# Indexes
#
#  index_order_attachments_on_order_id  (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class OrderAttachment < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :order, inverse_of: :order_attachments
  has_one_attached :file

  # R6-4 InquiryMessageの添付バリデーション（1ファイルの単純ガードのみで合計サイズ判定は避ける方針）を
  # 踏襲する。OrderAttachmentは1レコード=1ファイルのため、attachments_within_limitsの「件数」判定は
  # 「このOrderに既に何件のOrderAttachmentが存在するか」に読み替える。
  validate :file_must_be_attached
  validate :file_within_limits

  scope :visible_to_customer, -> { where(is_visible_to_customer: true) }

  private

  def file_must_be_attached
    errors.add(:file, "を選択してください") unless file.attached?
  end

  def file_within_limits
    return unless file.attached?

    settings = SystemSetting.current

    if order_id.present? && order.order_attachments.where.not(id: id).count >= settings.order_attachment_max_count
      errors.add(:file, "はこの案件につき#{settings.order_attachment_max_count}件までです")
    end

    return unless file.blob&.byte_size.to_i > settings.order_attachment_max_size_bytes

    errors.add(:file, "のサイズ上限は#{settings.order_attachment_max_size_mb}MBです")
  end
end
