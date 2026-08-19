require "rails_helper"

# 04 R5前ブロッカーG-10: 案件ステータス全35値（統廃合後31値）のシード投入を検証する。
RSpec.describe StatusSeeder do
  # 採番並行性テスト等がDatabaseCleaner truncationで実DBへコミットするため、トランザクショナル
  # フィクスチャだけでは他specの残留行を消せないことがある。既存件数に依存しない検証にするため、
  # 各exampleの直前で確実にクリアする。
  before { OrderStatus.delete_all }

  describe ".call" do
    it "OrderStatusを統廃合後の31値投入する" do
      described_class.call

      expect(OrderStatus.count).to eq(31)
    end

    it "統合・削除された旧コード（9/11/12/95）は投入しない" do
      described_class.call

      expect(OrderStatus.exists?(code: "9:作業進行再依頼")).to be false
      expect(OrderStatus.exists?(code: "11:対応・確認依頼（作業一旦停止）")).to be false
      expect(OrderStatus.exists?(code: "12:作業再開依頼")).to be false
      expect(OrderStatus.exists?(code: "95:強制解約（不正）")).to be false
    end

    it "受注(0)はDM-6決定どおり現状維持でis_system=trueのまま投入される" do
      described_class.call

      ordered = OrderStatus.find_by(code: OrderStatus::CODE_ORDERED)
      expect(ordered).to be_present
      expect(ordered.is_system).to be true
    end

    it "新たに追加した代表的なコードが投入される（不備チェック依頼・確認コールNG・検収確認コール依頼・解約処理待ち各月度）" do
      described_class.call

      %w[
        1:不備チェック依頼
        6:確認コールNG
        6-1:確認コール済（作業進行保留）
        13:検収確認コール依頼
        23:解約処理待ち（1月度解約案件）
        34:解約処理待ち（12月度解約案件）
      ].each do |code|
        expect(OrderStatus.exists?(code: code)).to be(true), "#{code} が投入されていない"
      end
    end

    it "sort_orderが原本のコード順（0受注→100:CLOSE）で連番になる" do
      described_class.call

      codes_in_order = OrderStatus.order(:sort_order).pluck(:code)
      expect(codes_in_order.first).to eq(OrderStatus::CODE_ORDERED)
      expect(codes_in_order.last).to eq("100:CLOSE")
    end

    it "2回呼んでも冪等（件数が変わらない）" do
      described_class.call
      described_class.call

      expect(OrderStatus.count).to eq(31)
    end

    it "R6-6: 完了/終了系5件（完了・キャンセル・解約・強制解約・CLOSE）だけis_completed=trueになる" do
      described_class.call

      completed_codes = OrderStatus.where(is_completed: true).pluck(:code)
      expect(completed_codes).to match_array(%w[16:完了 20:キャンセル 21:解約 22:強制解約 100:CLOSE])
    end

    it "R6-6: 解約処理待ち（月度別）はまだ処理が残るためis_completed=falseのまま投入される" do
      described_class.call

      expect(OrderStatus.find_by(code: "23:解約処理待ち（1月度解約案件）").is_completed).to be false
      expect(OrderStatus.find_by(code: "34:解約処理待ち（12月度解約案件）").is_completed).to be false
    end
  end

  describe "ContractStatus" do
    it "basic-design.md §9〜§12の9ステータス+起点(pending_check)を投入する" do
      described_class.call

      expect(ContractStatus.ordered.pluck(:code)).to eq(
        %w[
          pending_check returned being_corrected reapplication_pending recheck_pending
          confirm_call_pending confirm_call_done needs_reconfirmation
          contract_confirmation_pending contracted
        ]
      )
    end

    it "pending_check/contractedのみis_system=true（Order側のコードから直接参照される起点/終端）" do
      described_class.call

      system_codes = ContractStatus.where(is_system: true).pluck(:code)
      expect(system_codes).to match_array(%w[pending_check contracted])
    end
  end

  describe "InquiryStatus (R6-6 is_completed)" do
    it "各掲示板種別の終端コード（OK系/キャンセル、アフターのみ完了）だけis_completed=trueになる" do
      described_class.call

      expect(InquiryStatus.where(category: Inquiry::CATEGORY_POST_CONFIRM, is_completed: true).pluck(:code))
        .to match_array(%w[後確OK キャンセル])
      expect(InquiryStatus.where(category: Inquiry::CATEGORY_PRODUCTION, is_completed: true).pluck(:code))
        .to match_array(%w[制作OK キャンセル])
      expect(InquiryStatus.where(category: Inquiry::CATEGORY_INSPECTION, is_completed: true).pluck(:code))
        .to match_array(%w[検収コールOK キャンセル])
      expect(InquiryStatus.where(category: Inquiry::CATEGORY_AFTER, is_completed: true).pluck(:code))
        .to match_array(%w[完了])
    end

    it "非終端コード（対応中系）はis_completed=falseのまま投入される" do
      described_class.call

      expect(InquiryStatus.find_by(category: Inquiry::CATEGORY_AFTER, code: "対応中").is_completed).to be false
      expect(InquiryStatus.find_by(category: Inquiry::CATEGORY_AFTER, code: "対応済").is_completed).to be false
    end
  end

  describe "PaymentMethod" do
    it "口振/クレカ/おまとめの3値をis_system=trueで投入する" do
      described_class.call

      expect(PaymentMethod.ordered.pluck(:code, :label)).to eq(
        [
          [ PaymentMethod::CODE_BANK_TRANSFER, "預金口座振替" ],
          [ PaymentMethod::CODE_CREDIT, "クレジット" ],
          [ PaymentMethod::CODE_BUNDLED, "おまとめ" ]
        ]
      )
      expect(PaymentMethod.pluck(:is_system).uniq).to eq([ true ])
    end
  end
end
