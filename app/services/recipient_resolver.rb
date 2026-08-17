# 問い合わせ宛先解決（04 R4タスク1・2。Laravel InquiryRecipientResolver.php移植＋
# 決定D-11の「種別×ステータス→宛先」ルーティングを1サービスに統合）。
#
# 2つの解決経路を持つ（board-implementation-options.md §2-2で整理された区別のとおり）:
#   1. resolve_from_order: 案件から代理店・営業担当者・顧客を自動解決する（Laravel既存機能。
#      「宛先を投稿者が手動選択する際の候補」を提供する）
#   2. route_for: category×status_codeからrecipient_groupsを解決する（掲示板統合で追加された
#      「ステータス選択＝宛先自動決定」。05§5-1の転送先マトリクスに相当）
#
# recipients_for_inquiry はこの2経路をマージし、InquiryMessage#assign_recipients! にそのまま渡せる
# [{type:, id:}, ...] 形式で返す（type はRailsのクラス名文字列。polymorphic規約に合わせる）。
class RecipientResolver
  OrderRecipients = Struct.new(:agency, :sales_representative, :customer, keyword_init: true)
  Party = Struct.new(:type, :id, :name, :email, :has_email, keyword_init: true)

  def self.resolve_from_order(inquiry)
    new(inquiry).resolve_from_order
  end

  def self.route_for(category:, status_code:)
    RecipientGroup
      .joins(:inquiry_recipient_routes)
      .where(inquiry_recipient_routes: { category: category, status_code: status_code })
      .distinct
  end

  def self.recipients_for_inquiry(inquiry)
    new(inquiry).recipients_for_inquiry
  end

  def initialize(inquiry)
    @inquiry = inquiry
  end

  # 案件から代理店・営業担当者・顧客を解決する（宛先候補の提示用。メールなしでも返す＝
  # has_emailで送信可否を判定するのは呼び出し側の責務。Laravel resolveFromInquiry踏襲）。
  def resolve_from_order
    order = inquiry.order
    return OrderRecipients.new(agency: nil, sales_representative: nil, customer: nil) unless order

    OrderRecipients.new(
      agency:                party_for_agency(order.agency),
      sales_representative:  party_for_sales_representative(order.sales_representative),
      customer:               party_for_customer(order.customer)
    )
  end

  # 種別×ステータスのルーティング結果（recipient_group）＋案件経由の自動解決結果（agency/
  # sales_representative/customer。メールが無い宛先は送信不能なので除外する）をマージして返す。
  def recipients_for_inquiry
    order_parties = resolve_from_order.to_a.compact.select(&:has_email)
    routed_groups = self.class.route_for(category: inquiry.category, status_code: inquiry.status)

    order_parties.map { |party| { type: party.type, id: party.id } } +
      routed_groups.map { |group| { type: "RecipientGroup", id: group.id } }
  end

  private

  attr_reader :inquiry

  def party_for_agency(agency)
    return nil unless agency

    emails = [ agency.email_1, agency.email_2, agency.email_3, agency.email_4, agency.email_5 ].compact_blank
    Party.new(type: "Agency", id: agency.id, name: agency.name, email: emails.first, has_email: emails.any?)
  end

  def party_for_sales_representative(sales_representative)
    return nil unless sales_representative

    Party.new(type: "SalesRepresentative", id: sales_representative.id, name: sales_representative.name,
              email: sales_representative.email, has_email: sales_representative.email.present?)
  end

  def party_for_customer(customer)
    return nil unless customer

    Party.new(type: "Customer", id: customer.id, name: customer.name,
              email: customer.email, has_email: customer.email.present?)
  end
end
