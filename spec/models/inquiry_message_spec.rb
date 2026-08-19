require "rails_helper"

# R6-3: 添付ファイルの件数・サイズ上限をSystemSetting（システム設定画面）から動的に読むように
# 切り出した（旧 MAX_ATTACHMENTS / MAX_ATTACHMENT_SIZE class定数を撤去）。
# 既定値（5件/50MB）のまま動く既存挙動と、システム設定を変更すると上限も追従することの両方を確認する。
RSpec.describe InquiryMessage, type: :model, seed_status_catalog: true do
  def attach_dummy_file(message, size_bytes: 10, filename: "a.txt")
    message.attachments.attach(
      io: StringIO.new("a" * size_bytes),
      filename: filename,
      content_type: "text/plain"
    )
  end

  describe "添付件数の上限" do
    it "SystemSettingの既定値5件までは許可される" do
      message = build(:inquiry_message)
      5.times { |i| attach_dummy_file(message, filename: "file#{i}.txt") }

      expect(message).to be_valid
    end

    it "SystemSettingの既定値を超える6件目でエラーになる" do
      message = build(:inquiry_message)
      6.times { |i| attach_dummy_file(message, filename: "file#{i}.txt") }

      expect(message).not_to be_valid
      expect(message.errors[:attachments].join).to include("5件までです")
    end

    it "システム設定の上限値を変更すると、変更後の値でバリデーションされる" do
      SystemSetting.current.update!(inquiry_attachment_max_count: 2)

      message = build(:inquiry_message)
      3.times { |i| attach_dummy_file(message, filename: "file#{i}.txt") }

      expect(message).not_to be_valid
      expect(message.errors[:attachments].join).to include("2件までです")
    end
  end

  describe "添付サイズの上限" do
    it "SystemSettingの既定値50MB以下は許可される" do
      message = build(:inquiry_message)
      attach_dummy_file(message, size_bytes: 10)

      expect(message).to be_valid
    end

    it "SystemSettingの既定値50MBを超えるとエラーになる" do
      message = build(:inquiry_message)
      attach_dummy_file(message, size_bytes: 51.megabytes)

      expect(message).not_to be_valid
      expect(message.errors[:attachments].join).to include("50MB")
    end

    it "システム設定の上限値を変更すると、変更後の値でバリデーションされる" do
      SystemSetting.current.update!(inquiry_attachment_max_size_mb: 1)

      message = build(:inquiry_message)
      attach_dummy_file(message, size_bytes: 2.megabytes)

      expect(message).not_to be_valid
      expect(message.errors[:attachments].join).to include("1MB")
    end
  end
end
