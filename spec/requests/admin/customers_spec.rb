require "rails_helper"

# 04 R2完了条件: 「代理店ユーザで他代理店のCustomer/Order一覧・詳細・更新に到達できないことを
# request specで確認」。CustomerPolicy（app/policies/customer_policy.rb）のAgencyScope適用を検証する。
RSpec.describe "Admin::Customers", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                    system_authorization: true do
  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a1) { create(:agency, agency_group: group_a) }
  let!(:agency_a2) { create(:agency, agency_group: group_a) }
  let!(:agency_b)  { create(:agency, agency_group: group_b) }
  let!(:customer_a1) { create(:customer, agency: agency_a1, name: "顧客A1") }
  let!(:customer_a2) { create(:customer, agency: agency_a2, name: "顧客A2") }
  let!(:customer_b)  { create(:customer, agency: agency_b, name: "顧客B") }

  describe "admin(super_admin)は全顧客にCRUD可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全代理店の顧客が表示される" do
      get admin_customers_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer_a1.name, customer_a2.name, customer_b.name)
    end

    it "他代理店の顧客も詳細参照できる" do
      get admin_customer_path(customer_b)
      expect(response).to have_http_status(:ok)
    end

    it "更新できる" do
      patch admin_customer_path(customer_b), params: { customer: { name: "更新後" } }
      expect(customer_b.reload.name).to eq("更新後")
    end
  end

  describe "代理店ユーザーは自代理店の顧客のみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店の顧客のみ表示される" do
      get admin_customers_path
      expect(response.body).to include(customer_a1.name)
      expect(response.body).not_to include(customer_a2.name)
      expect(response.body).not_to include(customer_b.name)
    end

    it "自代理店の顧客は詳細参照できる" do
      get admin_customer_path(customer_a1)
      expect(response).to have_http_status(:ok)
    end

    it "同一グループ内でも他代理店の顧客詳細は403" do
      get admin_customer_path(customer_a2)
      expect(response).to have_http_status(:forbidden)
    end

    it "他代理店の顧客詳細は403" do
      get admin_customer_path(customer_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店の顧客は更新できる" do
      patch admin_customer_path(customer_a1), params: { customer: { name: "自己編集後" } }
      expect(response).to redirect_to(admin_customer_path(customer_a1))
      expect(customer_a1.reload.name).to eq("自己編集後")
    end

    it "他代理店の顧客更新は403で内容も変わらない" do
      patch admin_customer_path(customer_b), params: { customer: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
      expect(customer_b.reload.name).not_to eq("改ざん")
    end

    it "他代理店の顧客削除は403" do
      delete admin_customer_path(customer_b)
      expect(response).to have_http_status(:forbidden)
      expect(Customer.exists?(customer_b.id)).to eq(true)
    end

    it "agency_idパラメータを送っても無視される（他代理店への付け替え防止）" do
      patch admin_customer_path(customer_a1), params: { customer: { name: "x", agency_id: agency_b.id } }
      expect(customer_a1.reload.agency_id).to eq(agency_a1.id)
    end
  end

  describe "代理店グループユーザーは配下代理店の顧客のみ" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には配下代理店の顧客のみ表示される" do
      get admin_customers_path
      expect(response.body).to include(customer_a1.name, customer_a2.name)
      expect(response.body).not_to include(customer_b.name)
    end

    it "配下代理店の顧客詳細は参照できる" do
      get admin_customer_path(customer_a2)
      expect(response).to have_http_status(:ok)
    end

    it "配下外の代理店の顧客詳細は403" do
      get admin_customer_path(customer_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "配下外の代理店の顧客更新は403" do
      patch admin_customer_path(customer_b), params: { customer: { name: "改ざん" } }
      expect(response).to have_http_status(:forbidden)
    end
  end
end

# 04 R2追補: customer_numberの自動採番の並行安全性を、spec/models/customer_spec.rbのモデル層検証に
# 加えてHTTPリクエスト経由でも検証する。Rackテストクライアント（ActionDispatch::Integration::Session）は
# スレッドセーフではないため、スレッドごとに個別のSessionインスタンスを作って独立にOTPログインしてから
# POSTする（spec/support/otp_sign_in_helper.rbのsign_in_with_otp!と同じ手順を手動で展開したもの）。
# customer_spec.rbと同じ理由でトランザクショナルフィクスチャを無効化し、afterで明示的に後片付けする。
RSpec.describe "Admin::Customers 採番の並行安全性", type: :request,
                                                    seed_permission_catalog: true, seed_status_catalog: true,
                                                    system_authorization: true do
  self.use_transactional_tests = false

  after do
    Customer.delete_all
    UserSystemRole.delete_all
    User.delete_all
    SequenceCounter.delete_all
    Agency.delete_all
    AgencyGroup.delete_all
    # トランザクショナルフィクスチャを無効化しているため、:seed_permission_catalogタグが
    # before(:each)で投入したSystemPermission/SystemRoleもロールバックされず残ってしまう。
    # role_seeder_spec.rb等「SystemRole.count等が0から始まる」前提のspecを壊さないよう明示的に消す。
    SystemRolePermission.delete_all
    SystemRole.delete_all
    SystemPermission.delete_all
  end

  it "複数スレッド・複数セッションから同時にPOSTしても customer_number が重複しない" do
    agency = create(:agency)
    admin_role = SystemRole.find_by!(name: "admin")
    # customer_spec.rbと同じ理由（プール上限に対しメインスレッドも1本消費するため4に抑える）。
    thread_count = 4
    per_thread = 2

    # OTPコードはSecureRandom.random_numberの戻り値を固定した1つの値に統一する（スレッド間で
    # 共有される単なる定数スタブなので、スレッド生成前に1回だけ設定すれば競合しない）。
    allow(SecureRandom).to receive(:random_number).and_return(123_456)

    customer_numbers = []
    mutex = Mutex.new

    threads = Array.new(thread_count) do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          # FactoryBotの内部状態（シーケンス等）はスレッドセーフ性が保証されないため、
          # spec/models/customer_spec.rb・order_spec.rbと同じ方針でスレッド内はUser.create!を直接使う。
          admin_user = User.create!(
            name: "並行admin#{i}", email: "concurrent-admin-#{i}@example.com",
            password: "Password1234", password_confirmation: "Password1234"
          )
          UserSystemRole.create!(user: admin_user, system_role: admin_role)

          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post user_session_path, params: { user: { email: admin_user.email, password: "Password1234" } }
          session.post user_otp_path, params: { code: "123456" }

          per_thread.times do |j|
            name = "並行テスト顧客#{i}-#{j}"
            session.post admin_customers_path, params: { customer: { agency_id: agency.id, name: name } }
            customer = Customer.find_by!(agency_id: agency.id, name: name)
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
