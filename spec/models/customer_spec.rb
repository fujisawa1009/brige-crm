require "rails_helper"

# 04 R2タスク5・9: customer_numberの採番安全化（T-1是正）。Laravel現行の`static::count()+1`は
# 同時作成で重複する。SequenceCounter（app/models/sequence_counter.rb）のアトミックUPSERTで
# 是正されていることを、実際に複数スレッド・複数DBコネクションから同時作成して検証する。
#
# トランザクショナルフィクスチャ（デフォルトの use_transactional_fixtures）はスレッドをまたぐ
# 別コネクションの変更を隔離してしまい、真の並行性を検証できないため、このspecだけ無効化し、
# after内で明示的に後片付けする。
# == Schema Information
#
# Table name: customers
#
#  id                       :uuid             not null, primary key
#  address_detail           :string(200)
#  agency_customer_code     :string(50)
#  applicant_type           :string(20)
#  applied_at               :date
#  appointer_code           :string(20)
#  appointer_name           :string(50)
#  city                     :string(50)
#  confirm_staff_code       :string(20)
#  confirm_staff_name       :string(50)
#  consolidated_billing     :boolean
#  contact2_dept_phone      :string(20)
#  contact2_name            :string(100)
#  contact2_name_kana       :string(100)
#  contact2_title           :string(50)
#  contact_dept_phone       :string(20)
#  contact_name             :string(100)
#  contact_name_kana        :string(100)
#  contact_title            :string(50)
#  contracted_at            :date
#  contractor_name_kana     :string(255)
#  customer_number          :string(20)       not null
#  email                    :string(255)
#  fax_number               :string(20)
#  industry                 :string(50)
#  industry_sub             :string(50)
#  inventory_type           :string(50)
#  invoice_address          :string(500)
#  invoice_destination      :string(50)
#  invoice_name             :string(255)
#  invoice_name_kana        :string(255)
#  invoice_other_phone      :string(20)
#  invoice_phone            :string(20)
#  invoice_postal_code      :string(8)
#  lbc_code                 :string(20)
#  mobile_contact_person    :string(50)
#  mobile_phone             :string(20)
#  name                     :string(255)      not null
#  netmove_registered_at    :date
#  num_employees            :integer
#  num_offices              :integer
#  phone                    :string(20)
#  postal_code              :string(8)
#  prefecture               :string(20)
#  representative_name      :string(100)
#  representative_name_kana :string(100)
#  sales_mgmt_customer_code :string(20)
#  sms_mobile_number        :string(20)
#  status                   :string(50)       default("applied"), not null
#  town                     :string(100)
#  years_in_business        :string(20)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agency_id                :uuid             not null
#  created_by_id            :uuid
#  netmove_member_id        :string(50)
#  sales_representative_id  :uuid
#  updated_by_id            :uuid
#
# Indexes
#
#  index_customers_on_agency_id                (agency_id)
#  index_customers_on_applied_at               (applied_at)
#  index_customers_on_customer_number          (customer_number) UNIQUE
#  index_customers_on_name                     (name)
#  index_customers_on_sales_representative_id  (sales_representative_id)
#  index_customers_on_status                   (status)
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (sales_representative_id => sales_representatives.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe Customer, type: :model, seed_status_catalog: true do
  self.use_transactional_tests = false

  after do
    Customer.delete_all
    SequenceCounter.delete_all
    Agency.delete_all
    AgencyGroup.delete_all
  end

  describe "採番の並行安全性" do
    it "複数スレッド・複数コネクションから同時作成しても customer_number が重複しない" do
      agency = create(:agency)
      # プール上限(RAILS_MAX_THREADS既定5)に対し、メインスレッドも1本消費するため4に抑える
      # （5にするとConnectionTimeoutErrorが起きうる。database.ymlのmax_connections参照）。
      thread_count = 4
      per_thread = 4

      customer_numbers = []
      mutex = Mutex.new

      threads = Array.new(thread_count) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            per_thread.times do |i|
              customer = Customer.create!(agency: agency, name: "並行テスト顧客")
              mutex.synchronize { customer_numbers << customer.customer_number }
            end
          end
        end
      end
      threads.each(&:join)

      expect(customer_numbers.size).to eq(thread_count * per_thread)
      expect(customer_numbers.uniq.size).to eq(thread_count * per_thread) # 重複が無いこと
    end
  end

  describe "customer_number のフォーマット" do
    it "C-000001 形式で採番される" do
      agency = create(:agency)
      customer = Customer.create!(agency: agency, name: "顧客A")
      expect(customer.customer_number).to match(/\AC-\d{6}\z/)
    end
  end

  describe "status の既定値" do
    it "未指定なら CustomerStatus::CODE_APPLIED になる" do
      agency = create(:agency)
      customer = Customer.create!(agency: agency, name: "顧客B")
      expect(customer.status).to eq(CustomerStatus::CODE_APPLIED)
    end

    it "customer_statusesに存在しないコードは保存できない" do
      agency = create(:agency)
      customer = Customer.new(agency: agency, name: "顧客C", status: "存在しないコード")
      expect(customer).not_to be_valid
      expect(customer.errors[:status]).to be_present
    end
  end
end
