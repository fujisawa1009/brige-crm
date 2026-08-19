require "rails_helper"

# R6-3: システム設定（システム全体で1行のみのシングルトン）。
# SystemSetting.current が常に同一の1行を返すこと、上限値のバリデーション、
# 2件目の直接作成が弾かれることを検証する。
RSpec.describe SystemSetting, type: :model do
  describe ".current" do
    it "レコードが存在しなければDefault値で1件作成する" do
      expect { described_class.current }.to change(described_class, :count).from(0).to(1)

      setting = described_class.current
      expect(setting.inquiry_attachment_max_count).to eq(5)
      expect(setting.inquiry_attachment_max_size_mb).to eq(50)
    end

    it "既に1件あれば新規作成せず同じレコードを返す" do
      first = described_class.current

      expect { described_class.current }.not_to change(described_class, :count)
      expect(described_class.current.id).to eq(first.id)
    end
  end

  describe "#inquiry_attachment_max_size_bytes" do
    it "MB指定値をバイトへ変換する" do
      setting = described_class.current
      setting.update!(inquiry_attachment_max_size_mb: 10)

      expect(setting.inquiry_attachment_max_size_bytes).to eq(10.megabytes)
    end
  end

  describe "シングルトン制約" do
    it "2件目のレコードは作成できない" do
      described_class.current

      second = described_class.new(inquiry_attachment_max_count: 5, inquiry_attachment_max_size_mb: 50)

      expect(second).not_to be_valid
      expect(second.errors[:base]).to include("システム設定は1件のみ作成できます")
    end
  end

  describe "バリデーション" do
    subject(:setting) { described_class.current }

    it { is_expected.to validate_numericality_of(:inquiry_attachment_max_count).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:inquiry_attachment_max_size_mb).only_integer.is_greater_than(0) }

    it "件数上限に100を超える値は許可しない" do
      setting.inquiry_attachment_max_count = 101
      expect(setting).not_to be_valid
    end

    it "サイズ上限に500を超える値は許可しない" do
      setting.inquiry_attachment_max_size_mb = 501
      expect(setting).not_to be_valid
    end
  end
end
