require "rails_helper"

# 04 R2タスク5・9: order_numberの採番安全化（T-1是正）。ORD{年}{連番4桁}形式で、
# customer_spec.rbと同じ理由でトランザクショナルフィクスチャを無効化して複数コネクションから検証する。
# == Schema Information
#
# Table name: orders
#
#  id                             :uuid             not null, primary key
#  account_issued_at              :date
#  accounting_month               :string(6)
#  billing_password               :text
#  bridge_accounting_month        :string(6)
#  bridge_agency_name             :string(100)
#  bridge_migration               :string(5)
#  bridge_migration_order_number  :string(20)
#  bridge_sales_rep_name          :string(50)
#  bundle_target_order_number     :string(20)
#  bundled_billing                :string(5)
#  business_auth_doc              :string(5)
#  business_auth_doc_collected_at :date
#  business_proof                 :string(200)
#  cancelled_at                   :date
#  citation_applied               :string(5)
#  citation_count                 :integer
#  citation_existing_serial       :string(50)
#  citation_plan                  :string(50)
#  confirm_call_contact_name      :string(50)
#  confirm_call_notes             :text
#  confirm_call_preferred_date    :string(50)
#  confirm_call_remarks           :text
#  confirm_call_staff_name        :string(50)
#  confirm_call_time              :string(100)
#  consent_contact_age            :integer
#  consent_rep_age                :integer
#  consent_status                 :string(20)
#  contract_sent_at               :date
#  contract_start_date            :date
#  contract_status                :string(50)
#  domestic_citation_plan         :string(50)
#  elderly_consent                :string(5)
#  elderly_consent_collected_at   :date
#  external_link_applied          :string(5)
#  external_link_count            :integer
#  external_link_type             :string(20)
#  factor_notes                   :string(200)
#  finance_address_detail         :string(100)
#  finance_building               :string(100)
#  finance_city                   :string(50)
#  finance_division               :string(20)
#  finance_installer              :string(100)
#  finance_phone                  :string(20)
#  finance_postal_code            :string(8)
#  finance_prefecture             :string(20)
#  finance_town                   :string(100)
#  gbp_multilingual               :string(5)
#  google_ads_applied             :string(5)
#  google_ads_count               :integer
#  google_review_display          :string(5)
#  infobiz_applied                :string(5)
#  inspection_call_completed_at   :date
#  inspection_call_history        :text
#  inspection_call_ng_time        :string(100)
#  issued_at                      :date
#  language_selection             :string(100)
#  meo_existing_serial            :string(50)
#  meo_mgmt_number                :string(20)
#  meo_premium_applied            :string(5)
#  onerank_cms                    :string(5)
#  order_number                   :string(20)       not null
#  ordered_at                     :date
#  owlet_cms                      :string(5)
#  paper_address_note             :string(200)
#  payment_collected_at           :date
#  payment_doc_confirmed_at       :date
#  payment_method                 :string(50)
#  plus_applied                   :string(5)
#  portal_site_applied            :string(5)
#  remarks                        :text
#  reservation_system             :string(50)
#  review_heading                 :string(100)
#  s_plan_cms                     :string(5)
#  sales_mgmt_slip_number         :string(20)
#  shared_notes                   :text
#  status                         :string(50)       default("0:受注"), not null
#  terminated_at                  :date
#  termination_reason             :string(200)
#  toss_up_code                   :string(20)
#  work_completed_at              :date
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  agency_id                      :uuid             not null
#  contract_condition_id          :uuid             not null
#  created_by_id                  :uuid
#  customer_id                    :uuid             not null
#  member_id                      :string(20)
#  plan_id                        :uuid
#  product_initial_fee_id         :uuid
#  sales_representative_id        :uuid
#  serial_id                      :string(20)
#  store_id                       :uuid
#  updated_by_id                  :uuid
#
# Indexes
#
#  index_orders_on_agency_id                (agency_id)
#  index_orders_on_contract_condition_id    (contract_condition_id)
#  index_orders_on_customer_id              (customer_id)
#  index_orders_on_order_number             (order_number) UNIQUE
#  index_orders_on_plan_id                  (plan_id)
#  index_orders_on_product_initial_fee_id   (product_initial_fee_id)
#  index_orders_on_sales_representative_id  (sales_representative_id)
#  index_orders_on_status                   (status)
#  index_orders_on_store_id                 (store_id)
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (contract_condition_id => contract_conditions.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (customer_id => customers.id) ON DELETE => restrict
#  fk_rails_...  (plan_id => plans.id) ON DELETE => nullify
#  fk_rails_...  (product_initial_fee_id => product_initial_fees.id) ON DELETE => nullify
#  fk_rails_...  (sales_representative_id => sales_representatives.id) ON DELETE => nullify
#  fk_rails_...  (store_id => stores.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
RSpec.describe Order, type: :model, seed_status_catalog: true do
  self.use_transactional_tests = false

  after do
    ContractReview.delete_all
    Order.delete_all
    Customer.delete_all
    ContractCondition.delete_all
    SequenceCounter.delete_all
    Agency.delete_all
    AgencyGroup.delete_all
  end

  describe "採番の並行安全性" do
    it "複数スレッド・複数コネクションから同時作成しても order_number が重複しない" do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "並行テスト顧客")
      # プール上限(RAILS_MAX_THREADS既定5)に対し、メインスレッドも1本消費するため4に抑える
      # （5にするとConnectionTimeoutErrorが起きうる。database.ymlのmax_connections参照）。
      thread_count = 4
      per_thread = 4

      order_numbers = []
      mutex = Mutex.new

      threads = Array.new(thread_count) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            per_thread.times do
              order = Order.create!(agency: agency, customer: customer, contract_condition: contract_condition)
              mutex.synchronize { order_numbers << order.order_number }
            end
          end
        end
      end
      threads.each(&:join)

      expect(order_numbers.size).to eq(thread_count * per_thread)
      expect(order_numbers.uniq.size).to eq(thread_count * per_thread) # 重複が無いこと
    end
  end

  describe "order_number のフォーマット" do
    it "ORD{年}{連番4桁} 形式で採番される" do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "顧客")
      order = Order.create!(agency: agency, customer: customer, contract_condition: contract_condition)

      expect(order.order_number).to match(/\AORD\d{4}\d{4}\z/)
    end
  end

  describe "status の既定値" do
    it "未指定なら OrderStatus::CODE_ORDERED になる" do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "顧客")
      order = Order.create!(agency: agency, customer: customer, contract_condition: contract_condition)

      expect(order.status).to eq(OrderStatus::CODE_ORDERED)
    end
  end

  describe "payment_method（R5-5b: PaymentMethodマスタ参照）" do
    it "PaymentMethodに存在するcodeなら有効" do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "顧客")
      order = Order.new(agency: agency, customer: customer, contract_condition: contract_condition,
                         payment_method: PaymentMethod::CODE_CREDIT)

      expect(order).to be_valid
    end

    it "PaymentMethodに存在しないcodeなら無効" do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "顧客")
      order = Order.new(agency: agency, customer: customer, contract_condition: contract_condition,
                         payment_method: "存在しない支払方法")

      expect(order).not_to be_valid
      expect(order.errors[:payment_method]).to be_present
    end

    it "未指定（blank）は許容される" do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "顧客")
      order = Order.new(agency: agency, customer: customer, contract_condition: contract_condition)

      expect(order).to be_valid
    end
  end

  # 04 R5-1: 契約ワークフロー状態機械。design docの要求どおり遷移表をspecで固定する
  # （payment-integration.md §6「省略しない」の要求とcontract-confirmation-docs.mdの意図に倣う）。
  describe "transition_contract_to!（契約ワークフロー状態機械）" do
    let(:order) do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "顧客")
      Order.create!(agency: agency, customer: customer, contract_condition: contract_condition)
    end

    it "未着手(contract_status=nil)からcheck_requestedでpending_checkへ遷移する" do
      order.transition_contract_to!("check_requested")

      expect(order.reload.contract_status).to eq(ContractStatus::CODE_PENDING_CHECK)
    end

    it "遷移するたびにcontract_reviewsへfrom/to/eventが記録される" do
      order.transition_contract_to!("check_requested")

      review = order.contract_reviews.sole
      expect(review.event).to eq("check_requested")
      expect(review.from_status).to be_nil
      expect(review.to_status).to eq(ContractStatus::CODE_PENDING_CHECK)
      expect(review.performed_at).to be_present
    end

    it "reason/comment/returned_to/performed_byを記録できる" do
      staff = create(:user)
      order.transition_contract_to!("check_requested")

      order.transition_contract_to!(
        "check_returned", reason: "住所不備", comment: "郵便番号が空欄",
        returned_to: "sales_representative", performed_by: staff
      )

      review = order.contract_reviews.order(:performed_at).last
      expect(review.reason).to eq("住所不備")
      expect(review.comment).to eq("郵便番号が空欄")
      expect(review.returned_to).to eq("sales_representative")
      expect(review.performed_by).to eq(staff)
    end

    it "定義されていない遷移はInvalidContractTransitionを発生させ、contract_status/contract_reviewsは変化しない" do
      expect { order.transition_contract_to!("contract_confirmed") }
        .to raise_error(Order::InvalidContractTransition)

      expect(order.reload.contract_status).to be_nil
      expect(order.contract_reviews).to be_empty
    end

    it "不備チェック→差戻し→修正→再チェック→確認コール→契約確定まで一連の遷移を通せる" do
      order.transition_contract_to!("check_requested")
      order.transition_contract_to!("check_returned")
      order.transition_contract_to!("start_correction")
      order.transition_contract_to!("await_reapplication")
      order.transition_contract_to!("resubmitted")
      order.transition_contract_to!("check_passed")
      order.transition_contract_to!("call_done")
      order.transition_contract_to!("confirm")
      order.transition_contract_to!("contract_confirmed")

      expect(order.reload.contract_status).to eq(ContractStatus::CODE_CONTRACTED)
      expect(order.contract_reviews.count).to eq(9)
    end

    it "確認コール待ちで結果が不十分なら再確認要を経て確認コール待ちに戻れる" do
      order.transition_contract_to!("check_requested")
      order.transition_contract_to!("check_passed")
      order.transition_contract_to!("call_inconclusive")

      expect(order.reload.contract_status).to eq(ContractStatus::CODE_NEEDS_RECONFIRMATION)

      order.transition_contract_to!("call_pending_again")

      expect(order.reload.contract_status).to eq(ContractStatus::CODE_CONFIRM_CALL_PENDING)
    end

    it "契約確定(contracted)は終端状態でどのeventも受け付けない" do
      order.transition_contract_to!("check_requested")
      order.transition_contract_to!("check_passed")
      order.transition_contract_to!("call_done")
      order.transition_contract_to!("confirm")
      order.transition_contract_to!("contract_confirmed")

      expect { order.transition_contract_to!("check_requested") }
        .to raise_error(Order::InvalidContractTransition)
    end
  end

  # 2026-08-19 CEO決定（Q-45）: 暗号化列を全廃し平文保存へ変更した（billing_password含む）。
  # 保護はアクセス制御（RBAC＋Pundit）・監査ログの追跡除外・ログのパラメータフィルタ・
  # DB/バックアップのat-rest暗号化（R8で要件化）に依存する。
  describe "billing_password（Q-45: 平文保存）" do
    it "暗号化対象として宣言されていない" do
      expect(Order.encrypted_attributes.to_a.map(&:to_s)).to be_empty
    end

    it "DB上にそのまま平文で保存される" do
      agency = create(:agency)
      contract_condition = create(:contract_condition, agency: agency)
      customer = Customer.create!(agency: agency, name: "顧客")
      plaintext = "s3cret-billing-pass"
      order = Order.create!(
        agency: agency, customer: customer, contract_condition: contract_condition, billing_password: plaintext
      )

      raw_value = ActiveRecord::Base.connection.select_value(
        "SELECT billing_password FROM orders WHERE id = #{ActiveRecord::Base.connection.quote(order.id)}"
      )

      expect(raw_value).to eq(plaintext)
      expect(order.reload.billing_password).to eq(plaintext)
    end

    it "監査ログ(AuditLog)の追跡対象に含まれない（値をログに残さない）" do
      expect(Auditable::TRACKED_FIELDS.fetch("Order", [])).not_to include("billing_password")
    end
  end
end
