# 開発環境の画面確認用サンプルデータ（顧客約100件を中心に、主要テーブル一式に表示確認できる量を
# 入れる）。db/seeds.rb から development env 限定で読み込む。spec/factories の定義をそのまま使う
# ことで、各モデルのバリデーション（ステータスマスタ整合・採番等）を満たした有効なデータを
# 手早く用意する（本番コードには一切含めない、seeds専用の割り切り）。
#
# 冪等性: SAMPLE_GROUP_CODE の代理店グループが既に存在する場合は再生成しない
# （bin/rails db:seed を繰り返し実行してもデータが増殖しない）。
# トランザクションで包むのは、バリデーションエラー等で途中失敗した際に中途半端なデータを
# DBに残さないため（残ると上の冪等性チェックに引っかかって再実行だけでは復旧できなくなる）。
SAMPLE_GROUP_CODE = "SAMPLE-G1".freeze
return if AgencyGroup.exists?(group_code: SAMPLE_GROUP_CODE)

require "factory_bot"
FactoryBot.definition_file_paths = [ Rails.root.join("spec/factories") ]
FactoryBot.reload

PREFECTURES = %w[東京都 大阪府 神奈川県 愛知県 福岡県 北海道 宮城県 広島県 京都府 埼玉県].freeze
COMPANY_WORDS = %w[さくら 富士 みどり 青空 若葉 大和 湘南 北陸 深緑 陽だまり 銀河 星空 なでしこ 桜花 千歳 白鳥 万葉 飛鳥 潮風 山彦].freeze
COMPANY_TYPES = %w[商事 商店 工業 建設 フーズ メディカル デザイン 物流 コンサルティング テクノロジー クリニック 不動産 印刷 運輸 農園].freeze
PERSON_FAMILY_NAMES = %w[佐藤 鈴木 高橋 田中 渡辺 伊藤 山本 中村 小林 加藤].freeze
PERSON_GIVEN_NAMES = %w[太郎 花子 一郎 恵子 健太 美咲 大輔 由美 拓也 綾].freeze

def sample_company_name = "#{COMPANY_WORDS.sample}#{COMPANY_TYPES.sample}株式会社"
def sample_person_name = "#{PERSON_FAMILY_NAMES.sample} #{PERSON_GIVEN_NAMES.sample}"
def sample_phone = format("0#{[3, 6, 45, 52, 92].sample}-%04d-%04d", rand(1000..9999), rand(1000..9999))

puts "sample data seed: start"

ActiveRecord::Base.transaction do
  # --- 組織マスタ -----------------------------------------------------------
  agency_groups = [
    FactoryBot.create(:agency_group, group_code: SAMPLE_GROUP_CODE, name: "サンプル代理店グループA", service_type: "BridgePlus"),
    FactoryBot.create(:agency_group, name: "サンプル代理店グループB", service_type: "Bridge"),
    FactoryBot.create(:agency_group, name: "サンプル代理店グループC", service_type: "BridgePlus")
  ]

  agencies = agency_groups.flat_map do |group|
    Array.new(3) { FactoryBot.create(:agency, agency_group: group, name: "#{sample_company_name}代理店") }
  end

  sales_representatives = agencies.map { |agency| FactoryBot.create(:sales_representative, agency: agency, name: sample_person_name) }

  contract_conditions = agencies.map { |agency| FactoryBot.create(:contract_condition, agency: agency) }
  contract_conditions_by_agency = contract_conditions.group_by(&:agency_id)

  # --- 商材マスタ -----------------------------------------------------------
  products = Array.new(5) { FactoryBot.create(:product, name: "#{COMPANY_WORDS.sample}プラン商材") }
  plans = products.flat_map { |product| Array.new(2) { FactoryBot.create(:plan, product: product, monthly_fee: [ 3000, 5000, 8000, 12_000 ].sample) } }
  initial_fees = products.map { |product| FactoryBot.create(:product_initial_fee, product: product, amount: [ 5000, 10_000, 30_000 ].sample) }
  products.each { |product| Array.new(2) { FactoryBot.create(:product_option, product: product) } }

  option_groups = Array.new(2) { FactoryBot.create(:option_group) }
  option_groups.each { |group| Array.new(3) { FactoryBot.create(:option_value, option_group: group) } }

  Array.new(3) { FactoryBot.create(:production_company) }
  Array.new(3) { FactoryBot.create(:sales_material) }

  products.first(2).each do |product|
    template = FactoryBot.create(:form_template, product: product)
    step = FactoryBot.create(:form_step, form_template: template)
    Array.new(2) { FactoryBot.create(:form_field, form_step: step) }
  end

  # --- ユーザー・宛先グループ -------------------------------------------------
  staff_users = Array.new(3) { |i| FactoryBot.create(:user, name: sample_person_name, email: "staff#{i + 1}@example.com") }
  agencies.first(3).each { |agency| FactoryBot.create(:user, agency: agency, name: sample_person_name) }

  recipient_groups = Array.new(3) { FactoryBot.create(:recipient_group) }
  recipient_groups.each do |group|
    staff_users.sample(2).each { |user| FactoryBot.create(:recipient_group_member, recipient_group: group, recipient: user) }
  end

  Inquiry::CATEGORIES.each_with_index do |category, index|
    status_code = InquiryStatus.where(category: category).order(:sort_order).pick(:code)
    FactoryBot.create(:inquiry_recipient_route, category: category, status_code: status_code,
                                                 recipient_group: recipient_groups[index % recipient_groups.size])
  end

  notification_templates = NotificationTemplate::TEMPLATE_TYPES.keys.map { |type| FactoryBot.create(:notification_template, template_type: type) }
  5.times do
    status = Notification::STATUSES.sample
    FactoryBot.create(:notification,
                       target_type: Notification::TARGET_TYPES.sample,
                       status: status,
                       scheduled_at: (status == Notification::STATUS_SCHEDULED ? 1.day.from_now : nil),
                       notification_template: notification_templates.sample)
  end

  # --- 顧客（約100件） --------------------------------------------------------
  customer_status_codes = CustomerStatus.order(:sort_order).pluck(:code)
  order_status_codes = OrderStatus.order(:sort_order).pluck(:code)

  customers = Array.new(100) do |i|
    agency = agencies.sample
    status = rand < 0.4 ? customer_status_codes.sample : CustomerStatus::CODE_APPLIED
    prefecture = PREFECTURES.sample
    city = "#{prefecture.delete_suffix('都').delete_suffix('道').delete_suffix('府').delete_suffix('県')}市"

    customer = FactoryBot.create(:customer,
                                  agency: agency,
                                  sales_representative: sales_representatives.select { |r| r.agency_id == agency.id }.sample,
                                  name: sample_company_name,
                                  status: status,
                                  prefecture: prefecture,
                                  city: city,
                                  phone: sample_phone,
                                  email: "customer#{i}@example.com",
                                  contact_name: sample_person_name,
                                  applied_at: rand(1..365).days.ago.to_date)

    FactoryBot.create(:store, customer: customer, store_name: "#{customer.name} 本店") if rand < 0.4

    customer
  end
  puts "sample data seed: created #{customers.size} customers"

  # --- 案件（顧客の約6割） -----------------------------------------------------
  orders = customers.sample((customers.size * 0.6).round).map do |customer|
    FactoryBot.create(:order,
                       customer: customer,
                       agency: customer.agency,
                       store: customer.stores.first,
                       contract_condition: contract_conditions_by_agency.fetch(customer.agency_id).sample,
                       plan: plans.sample,
                       product_initial_fee: initial_fees.sample,
                       status: rand < 0.3 ? order_status_codes.sample : OrderStatus::CODE_ORDERED,
                       ordered_at: rand(1..300).days.ago)
  end
  puts "sample data seed: created #{orders.size} orders"

  # --- 問い合わせ（案件の一部） -------------------------------------------------
  inquiries = orders.sample([ orders.size, 25 ].min).map do |order|
    FactoryBot.create(:inquiry, order: order, category: Inquiry::CATEGORIES.sample)
  end
  inquiries.each { |inquiry| Array.new(rand(1..3)) { FactoryBot.create(:inquiry_message, inquiry: inquiry) } }
  puts "sample data seed: created #{inquiries.size} inquiries"
end

puts "sample data seed: done"
