# R6-8 ファイル管理基盤。file必須（presenceバリデーション）のため、build時点でダミーファイルを
# 自動添付する（inquiry_messagesのattach_dummy_fileパターンと異なり、OrderAttachmentは1レコード=
# 1ファイルのため常に添付済みの状態で作れないとfactoryとして使いづらいための判断）。
# == Schema Information
#
# Table name: order_attachments
#
#  id                     :uuid             not null, primary key
#  file_type              :string(50)
#  is_visible_to_customer :boolean          default(FALSE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  created_by_id           :uuid
#  order_id                :uuid             not null
#  updated_by_id           :uuid
#
FactoryBot.define do
  factory :order_attachment do
    association :order

    after(:build) do |order_attachment|
      next if order_attachment.file.attached?

      order_attachment.file.attach(
        io: StringIO.new("dummy file content"),
        filename: "dummy.txt",
        content_type: "text/plain"
      )
    end
  end
end
