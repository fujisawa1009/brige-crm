require "rails_helper"

# 04「リスク・注意」7の残課題: RecipientGroup / InquiryRecipientRoute の初期データ投入
# （legacy-research/05-legacy-spec-fields.md §5-1/§5-2）を検証する。
RSpec.describe InquiryRecipientSeeder do
  # InquiryRecipientRoute は inquiry_statuses に存在するコードしか受け付けないため、
  # ステータスマスタを先に投入しておく（db/seeds.rb と同じ実行順）。
  before do
    InquiryRecipientRoute.delete_all
    RecipientGroup.delete_all
    StatusSeeder.call
  end

  describe ".call" do
    it "05 §5-1/§5-2 の送付先に対応する宛先グループ5件を投入する" do
      described_class.call

      expect(RecipientGroup.count).to eq(5)
      expect(RecipientGroup.pluck(:name)).to contain_exactly(
        "営業担当（販売店）",
        "FT管理（契約・請求）",
        "FT運用（システム）",
        "FTコール（確認・検収）",
        "FT受注管理"
      )
    end

    it "現行の転送先アドレスをdescriptionに記録する（運用でメンバーを割り当てるための手がかり）" do
      described_class.call

      expect(RecipientGroup.find_by(name: "FT運用（システム）").description).to include("bridgeplus_kanri@ftgroup.co.jp")
      expect(RecipientGroup.find_by(name: "FTコール（確認・検収）").description).to include("ecotech-order@if-n.co.jp")
      expect(RecipientGroup.find_by(name: "FT受注管理").description).to include("bridgeplus_order@ftgroup.co.jp")
    end

    it "05 §5-1 の「販売店にメール」以外の4ルートを投入する" do
      described_class.call

      routes = InquiryRecipientRoute.includes(:recipient_group).map do |route|
        [ route.category, route.status_code, route.recipient_group.name ]
      end

      expect(routes).to contain_exactly(
        [ Inquiry::CATEGORY_POST_CONFIRM, "再申請", "FTコール（確認・検収）" ],
        [ Inquiry::CATEGORY_PRODUCTION, "FT確認依頼", "FT受注管理" ],
        [ Inquiry::CATEGORY_PRODUCTION, "再申請", "FT受注管理" ],
        [ Inquiry::CATEGORY_INSPECTION, "再申請", "FT受注管理" ]
      )
    end

    it "「販売店にメール」のステータス（後確OK等）はルートを作らない（案件経由で自動送信されるため）" do
      described_class.call

      expect(InquiryRecipientRoute.exists?(category: Inquiry::CATEGORY_POST_CONFIRM, status_code: "後確OK")).to be false
      expect(InquiryRecipientRoute.exists?(category: Inquiry::CATEGORY_PRODUCTION, status_code: "営業部対応依頼")).to be false
    end

    it "RecipientResolver.route_for から引ける（通知の宛先解決に実際に効く）" do
      described_class.call

      groups = RecipientResolver.route_for(category: Inquiry::CATEGORY_PRODUCTION, status_code: "FT確認依頼")
      expect(groups.map(&:name)).to eq([ "FT受注管理" ])
    end

    it "再実行しても増殖しない（冪等）" do
      described_class.call
      described_class.call

      expect(RecipientGroup.count).to eq(5)
      expect(InquiryRecipientRoute.count).to eq(4)
    end

    it "運用側で編集したdescription・is_activeは再実行で上書きしない" do
      described_class.call
      group = RecipientGroup.find_by!(name: "FT受注管理")
      group.update!(description: "運用で書き換えた説明", is_active: false)

      described_class.call

      group.reload
      expect(group.description).to eq("運用で書き換えた説明")
      expect(group.is_active).to be false
    end

    # 外部委託先の共有アドレスはUser/ProductionCompanyのレコードが無いと宛先にできないため、
    # メンバー登録は運用作業として残す（seederが勝手にUserを作らないことの確認）。
    it "グループのメンバーは投入しない（運用作業として残す）" do
      described_class.call

      expect(RecipientGroupMember.count).to eq(0)
    end
  end
end
