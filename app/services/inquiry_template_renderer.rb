# 問い合わせ返信テンプレートの差し込み変数展開（R6-4。legacy-research/13-faq-templates.md §2）。
# `%{var}` 形式（同書「Rails版注記」の候補どおり。Liquid等の外部gemは導入せず標準の文字列置換で足りる
# 単純さのため不採用）を対象のInquiryが持つOrder/Customer/Store等の実データへ置換する。
#
# 未対応の変数名や、参照先（store等）がnilで値を引けない場合はKeyError等で落とさず空文字へ
# フォールバックする（テンプレート本文の入力ミスや、店舗未設定の案件でテンプレートを使う運用を
# 例外で止めない。プレースホルダーがそのまま残るより空文字の方が実害が小さい）。
class InquiryTemplateRenderer
  # 対応する差し込み変数と説明（テンプレート編集画面のヒント表示にも使う）。
  VARIABLES = {
    "customer_name"  => "顧客名（会社名）",
    "store_name"     => "店舗名",
    "order_number"   => "案件番号",
    "inquiry_number" => "問い合わせ番号"
  }.freeze

  def self.render(inquiry_template, inquiry)
    new(inquiry_template, inquiry).render
  end

  def initialize(inquiry_template, inquiry)
    @inquiry_template = inquiry_template
    @inquiry = inquiry
  end

  def render
    variables.reduce(inquiry_template.body.to_s) do |text, (key, value)|
      text.gsub("%{#{key}}", value.to_s)
    end
  end

  private

  attr_reader :inquiry_template, :inquiry

  def variables
    order = inquiry&.order
    {
      "customer_name"  => order&.customer&.name,
      "store_name"     => order&.store&.store_name,
      "order_number"   => order&.order_number,
      "inquiry_number" => inquiry&.inquiry_number
    }
  end
end
