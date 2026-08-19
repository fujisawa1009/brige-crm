# 開発環境の画面確認用サンプルデータ（顧客・案件・問い合わせ）。db/seeds.rb から development env
# 限定で読み込む。7e12d94でLaravel版の実データ（代理店グループ145・代理店128・商材/プラン54）を
# db/seeds/へ移植した際に旧db/seeds/sample_data.rbごと廃止されたが、実データの代理店・商材は
# 「マスタ」であって画面確認用の顧客・案件・問い合わせが無いと一覧/詳細/検索画面を確認できないため、
# 実データの代理店・商材に紐づく形で復元する（旧版のようにSAMPLE_GROUP_CODEで別の代理店グループ・
# 商材を作らない。実マスタと重複させないため）。
#
# 冪等性: 対象代理店（先頭10件）にすでにSalesRepresentativeが存在する場合は再生成しない。
# トランザクションで包むのは、バリデーションエラー等で途中失敗した際に中途半端なデータを
# DBに残さないため（残ると上の冪等性チェックに引っかかって再実行だけでは復旧できなくなる）。
return unless Rails.env.development?
return if Agency.count.zero? || Plan.count.zero?

target_agencies = Agency.order(:created_at).limit(10)
return if SalesRepresentative.where(agency_id: target_agencies.select(:id)).exists?

require "factory_bot"
FactoryBot.definition_file_paths = [ Rails.root.join("spec/factories") ]
FactoryBot.reload

PREFECTURES = %w[東京都 大阪府 神奈川県 愛知県 福岡県 北海道 宮城県 広島県 京都府 埼玉県].freeze
PERSON_FAMILY_NAMES = %w[佐藤 鈴木 高橋 田中 渡辺 伊藤 山本 中村 小林 加藤].freeze
PERSON_GIVEN_NAMES = %w[太郎 花子 一郎 恵子 健太 美咲 大輔 由美 拓也 綾].freeze
COMPANY_WORDS = %w[さくら 富士 みどり 青空 若葉 大和 湘南 北陸 深緑 陽だまり 銀河 星空 なでしこ 桜花 千歳 白鳥 万葉 飛鳥 潮風 山彦].freeze
COMPANY_TYPES = %w[商事 商店 工業 建設 フーズ メディカル デザイン 物流 コンサルティング テクノロジー クリニック 不動産 印刷 運輸 農園].freeze

def sample_company_name = "#{COMPANY_WORDS.sample}#{COMPANY_TYPES.sample}株式会社"
def sample_person_name = "#{PERSON_FAMILY_NAMES.sample} #{PERSON_GIVEN_NAMES.sample}"
def sample_phone = format("0#{[ 3, 6, 45, 52, 92 ].sample}-%04d-%04d", rand(1000..9999), rand(1000..9999))

puts "sample transactions seed: start"

ActiveRecord::Base.transaction do
  agencies = target_agencies.to_a
  sales_representatives = agencies.map { |agency| FactoryBot.create(:sales_representative, agency: agency, name: sample_person_name) }
  contract_conditions = agencies.map { |agency| FactoryBot.create(:contract_condition, agency: agency) }
  contract_conditions_by_agency = contract_conditions.group_by(&:agency_id)

  plans = Plan.limit(20).to_a
  initial_fees = ProductInitialFee.all.to_a

  customer_status_codes = CustomerStatus.order(:sort_order).pluck(:code)
  order_status_codes = OrderStatus.order(:sort_order).pluck(:code)

  customers = Array.new(80) do |i|
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
                                  email: "sample-customer#{i}@example.com",
                                  contact_name: sample_person_name,
                                  applied_at: rand(1..365).days.ago.to_date)

    FactoryBot.create(:store, customer: customer, store_name: "#{customer.name} 本店") if rand < 0.4

    customer
  end
  puts "sample transactions seed: created #{customers.size} customers"

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
  puts "sample transactions seed: created #{orders.size} orders"

  inquiries = orders.sample([ orders.size, 20 ].min).map do |order|
    FactoryBot.create(:inquiry, order: order, category: Inquiry::CATEGORIES.sample)
  end
  inquiries.each { |inquiry| Array.new(rand(1..3)) { FactoryBot.create(:inquiry_message, inquiry: inquiry) } }
  puts "sample transactions seed: created #{inquiries.size} inquiries"
end

puts "sample transactions seed: done"
