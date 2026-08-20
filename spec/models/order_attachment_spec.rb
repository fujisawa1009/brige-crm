require "rails_helper"

# R6-8 ファイル管理基盤。file presenceと、SystemSetting(order_attachment_max_count/max_size_mb)
# 由来の件数・サイズ上限バリデーションを検証する（InquiryMessageの添付バリデーションspecと同型）。
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
RSpec.describe OrderAttachment, type: :model, seed_status_catalog: true do
  def attach_dummy_file(order_attachment, size_bytes: 10, filename: "a.txt")
    order_attachment.file.attach(
      io: StringIO.new("a" * size_bytes),
      filename: filename,
      content_type: "text/plain"
    )
  end

  describe "fileのpresence" do
    it "fileが未添付だと保存できない" do
      order_attachment = build(:order_attachment)
      order_attachment.file.detach

      expect(order_attachment).not_to be_valid
      expect(order_attachment.errors[:file]).to be_present
    end

    it "fileが添付されていれば保存できる" do
      order_attachment = build(:order_attachment)
      expect(order_attachment).to be_valid
    end
  end

  describe "is_visible_to_customerの既定値" do
    it "既定はfalse（社内限定）" do
      order_attachment = create(:order_attachment)
      expect(order_attachment.is_visible_to_customer).to eq(false)
    end
  end

  describe "添付件数の上限（1案件あたり）" do
    it "SystemSettingの既定値20件までは許可される" do
      order = create(:order)
      19.times { create(:order_attachment, order: order) }

      new_attachment = build(:order_attachment, order: order)
      expect(new_attachment).to be_valid
    end

    it "SystemSettingの既定値を超える21件目でエラーになる" do
      order = create(:order)
      20.times { create(:order_attachment, order: order) }

      new_attachment = build(:order_attachment, order: order)
      expect(new_attachment).not_to be_valid
      expect(new_attachment.errors[:file].join).to include("20件までです")
    end

    it "既存レコードの更新（件数は増えない）ではカウント対象に自分自身を含めない" do
      order_attachment = create(:order_attachment)

      order_attachment.file_type = "契約書"
      expect(order_attachment).to be_valid
    end

    it "システム設定の上限値を変更すると、変更後の値でバリデーションされる" do
      SystemSetting.current.update!(order_attachment_max_count: 1)
      order = create(:order)
      create(:order_attachment, order: order)

      new_attachment = build(:order_attachment, order: order)
      expect(new_attachment).not_to be_valid
      expect(new_attachment.errors[:file].join).to include("1件までです")
    end
  end

  describe "添付サイズの上限" do
    it "SystemSettingの既定値50MB以下は許可される" do
      order_attachment = build(:order_attachment)
      order_attachment.file.detach
      attach_dummy_file(order_attachment, size_bytes: 10)

      expect(order_attachment).to be_valid
    end

    it "SystemSettingの既定値50MBを超えるとエラーになる" do
      order_attachment = build(:order_attachment)
      order_attachment.file.detach
      attach_dummy_file(order_attachment, size_bytes: 51.megabytes)

      expect(order_attachment).not_to be_valid
      expect(order_attachment.errors[:file].join).to include("50MB")
    end

    it "システム設定の上限値を変更すると、変更後の値でバリデーションされる" do
      SystemSetting.current.update!(order_attachment_max_size_mb: 1)

      order_attachment = build(:order_attachment)
      order_attachment.file.detach
      attach_dummy_file(order_attachment, size_bytes: 2.megabytes)

      expect(order_attachment).not_to be_valid
      expect(order_attachment.errors[:file].join).to include("1MB")
    end
  end
end
