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

  # 送信用の宛先展開（Laravel InquiryRecipientResolver#expandForSend 移植。メール送信欠落の補完）。
  # recipients は [{type:, id:}, ...]（type は InquiryMessageRecipient#recipient_type と同じ Rails
  # クラス名文字列: Agency / SalesRepresentative / Customer / User / RecipientGroup）。
  def self.expand_for_send(recipients)
    new.expand_for_send(recipients)
  end

  # inquiry は resolve_from_order 系だけが使う。expand_for_send は type/id 直指定で解決するため
  # inquiry 不要（nil 可）。
  def initialize(inquiry = nil)
    @inquiry = inquiry
  end

  # 送信用にメールアドレスを完全展開する（Laravel expandForSend 踏襲）。
  # recipient_group はメンバー（User/ProductionCompany）を全展開し、宛先1件＝1エントリにする。
  # メールを持たないエントリは除外する（送信不能な宛先で success/failed 集計を汚さない）。
  # 戻り値: [{ type:, id:, label:, emails: [代表, cc...] }, ...]
  def expand_for_send(recipients)
    recipients.flat_map { |item| expand_single(item.fetch(:type), item.fetch(:id)) }
              .select { |entry| entry[:emails].present? }
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
  #
  # 2026-08-19 v5 CEO決定（R4追補・notification-matrix.md §3-13）: is_visible_to_agent=false の
  # 問い合わせ（社内限定のやり取り。InquiryPolicy#show?が代理店/代理店グループから不可視にする対象）は、
  # 代理店へのメール送信も同様に止める（画面で見えないのにメールだけ届く食い違いを解消）。
  # 営業担当者（SalesRepresentative）・顧客は InquiryPolicy の可視性制御の対象外（別モデル・別画面）
  # のため対象外＝現行どおり全投稿で含める。
  def recipients_for_inquiry
    order_parties = resolve_from_order.to_a.compact.select(&:has_email)
    order_parties = order_parties.reject { |party| party.type == "Agency" } unless inquiry.is_visible_to_agent?
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

  # 単一宛先を type/id から展開する（Laravel expandSingle 移植。preview 経路は現行不要のため送信用のみ）。
  # RecipientGroup 以外は自身のメールを持つ1エントリ、RecipientGroup はメンバーを複数エントリへ展開する。
  def expand_single(type, id)
    case type
    when "Agency"
      agency = Agency.find_by(id: id)
      return [] unless agency

      emails = [ agency.email_1, agency.email_2, agency.email_3, agency.email_4, agency.email_5 ].compact_blank
      [ { type: "Agency", id: agency.id, label: "代理店: #{agency.name}", emails: emails } ]
    when "SalesRepresentative"
      rep = SalesRepresentative.find_by(id: id)
      return [] unless rep

      [ { type: "SalesRepresentative", id: rep.id, label: "営業担当者: #{rep.name}", emails: [ rep.email ].compact_blank } ]
    when "Customer"
      customer = Customer.find_by(id: id)
      return [] unless customer

      [ { type: "Customer", id: customer.id, label: "顧客: #{customer.name}", emails: [ customer.email ].compact_blank } ]
    when "User"
      user = User.find_by(id: id)
      return [] unless user

      [ { type: "User", id: user.id, label: "ユーザー: #{user.name}", emails: [ user.email ].compact_blank } ]
    when "RecipientGroup"
      group = RecipientGroup.find_by(id: id)
      return [] unless group

      resolve_group_members(group)
    else
      []
    end
  end

  # グループのメンバー（User/ProductionCompany）を、メール付きの送信エントリ配列へ展開する
  # （Laravel resolveGroupMembers 移植。メール無しメンバーは除外）。
  def resolve_group_members(group)
    group.recipient_group_members.filter_map do |member|
      case member.recipient_type
      when "User"
        user = member.recipient
        next if user&.email.blank?

        { type: "User", id: user.id, label: "ユーザー: #{user.name}", emails: [ user.email ] }
      when "ProductionCompany"
        company = member.recipient
        next if company&.email.blank?

        { type: "ProductionCompany", id: company.id, label: "制作会社: #{company.name}", emails: [ company.email ] }
      end
    end
  end
end
