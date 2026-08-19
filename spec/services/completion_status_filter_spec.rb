require "rails_helper"

# R6-6: 一覧の「完了済みを含む」検索。Order・Inquiry両方から使い回す共通Filterオブジェクトの
# ロジックを、Orderを題材に単体で検証する（呼び出し側controllerの結線はspec/requests側で確認）。
RSpec.describe CompletionStatusFilter, seed_status_catalog: true do
  let!(:agency) { create(:agency) }
  let!(:customer) { create(:customer, agency: agency) }
  let!(:contract_condition) { create(:contract_condition, agency: agency) }
  let!(:active_order) do
    create(:order, agency: agency, customer: customer, contract_condition: contract_condition,
                    status: "10:作業進行中")
  end
  let!(:completed_order) do
    create(:order, agency: agency, customer: customer, contract_condition: contract_condition,
                    status: "16:完了")
  end
  let!(:cancelled_order) do
    create(:order, agency: agency, customer: customer, contract_condition: contract_condition,
                    status: "20:キャンセル")
  end

  subject(:filter) { described_class.new(status_klass: OrderStatus) }

  describe "#apply" do
    it "include_completedが未指定なら完了/終了系ステータス（is_completed:true）の行を除外する" do
      result = filter.apply(Order.all, include_completed: nil)

      expect(result).to include(active_order)
      expect(result).not_to include(completed_order, cancelled_order)
    end

    it "include_completedが真値（\"1\"）なら全件返す" do
      result = filter.apply(Order.all, include_completed: "1")

      expect(result).to include(active_order, completed_order, cancelled_order)
    end

    it "include_completedがtrue（boolean）でも全件返す" do
      result = filter.apply(Order.all, include_completed: true)

      expect(result).to include(active_order, completed_order, cancelled_order)
    end

    it "include_completedが\"0\"や空文字なら除外を適用する（フォームのchecked=falseと同義）" do
      result = filter.apply(Order.all, include_completed: "0")

      expect(result).not_to include(completed_order)

      result_blank = filter.apply(Order.all, include_completed: "")
      expect(result_blank).not_to include(completed_order)
    end

    it "is_completedなマスタ行が1件も無くても全件を返す（where.notに空配列を渡した場合の安全側動作）" do
      OrderStatus.update_all(is_completed: false)

      result = filter.apply(Order.all, include_completed: nil)

      expect(result).to include(active_order, completed_order, cancelled_order)
    end
  end
end
