require "rails_helper"

# 04 R4タスク1・完了条件: 「代理店ユーザで他代理店のInquiry/InquiryMessageの一覧・詳細・
# メッセージ投稿に到達できないことをrequest specで確認」（R1/R2/R3で必須とされた参照制御パターンを
# R4へ適用）。InquiryPolicy（案件経由の間接スコープ + is_visible_to_agent）を検証する。
RSpec.describe "Admin::Inquiries", type: :request, seed_permission_catalog: true, seed_status_catalog: true,
                                    system_authorization: true do
  include ActiveJob::TestHelper

  let!(:group_a) { create(:agency_group) }
  let!(:group_b) { create(:agency_group) }
  let!(:agency_a1) { create(:agency, agency_group: group_a, email_1: "a1@example.com") }
  let!(:agency_a2) { create(:agency, agency_group: group_a) }
  let!(:agency_b)  { create(:agency, agency_group: group_b) }
  let!(:customer_a1) { create(:customer, agency: agency_a1) }
  let!(:customer_a2) { create(:customer, agency: agency_a2) }
  let!(:customer_b)  { create(:customer, agency: agency_b) }
  let!(:order_a1) { create(:order, agency: agency_a1, customer: customer_a1) }
  let!(:order_a2) { create(:order, agency: agency_a2, customer: customer_a2) }
  let!(:order_b)  { create(:order, agency: agency_b, customer: customer_b) }
  let!(:inquiry_a1) { create(:inquiry, order: order_a1) }
  let!(:inquiry_a2) { create(:inquiry, order: order_a2) }
  let!(:inquiry_b)  { create(:inquiry, order: order_b) }

  describe "admin(super_admin)は全問い合わせにアクセス可能" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "一覧に全代理店の問い合わせが表示される" do
      get admin_inquiries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(inquiry_a1.inquiry_number, inquiry_a2.inquiry_number, inquiry_b.inquiry_number)
    end

    it "他代理店の問い合わせも詳細参照できる" do
      get admin_inquiry_path(inquiry_b)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "代理店ユーザーは自代理店の問い合わせのみ" do
    let!(:agency_user) { user_with_role("代理店用", agency: agency_a1) }

    before { sign_in_with_otp!(agency_user) }

    it "一覧には自代理店の問い合わせのみ表示される" do
      get admin_inquiries_path
      expect(response.body).to include(inquiry_a1.inquiry_number)
      expect(response.body).not_to include(inquiry_a2.inquiry_number)
      expect(response.body).not_to include(inquiry_b.inquiry_number)
    end

    it "自代理店の問い合わせは詳細参照できる" do
      get admin_inquiry_path(inquiry_a1)
      expect(response).to have_http_status(:ok)
    end

    it "同一グループ内でも他代理店の問い合わせ詳細は403" do
      get admin_inquiry_path(inquiry_a2)
      expect(response).to have_http_status(:forbidden)
    end

    it "他代理店の問い合わせ詳細は403" do
      get admin_inquiry_path(inquiry_b)
      expect(response).to have_http_status(:forbidden)
    end

    it "is_visible_to_agent=false の自代理店問い合わせは一覧にも詳細にも出ない" do
      hidden = create(:inquiry, order: order_a1, is_visible_to_agent: false)

      get admin_inquiries_path
      expect(response.body).not_to include(hidden.inquiry_number)

      get admin_inquiry_path(hidden)
      expect(response).to have_http_status(:forbidden)
    end

    it "他代理店の問い合わせへメッセージ投稿は403で、メッセージも増えない" do
      expect {
        post admin_inquiry_inquiry_messages_path(inquiry_b), params: { inquiry_message: { body: "改ざん投稿" } }
      }.not_to change { inquiry_b.inquiry_messages.count }
      expect(response).to have_http_status(:forbidden)
    end

    it "自代理店の問い合わせへはメッセージ投稿できる" do
      expect {
        post admin_inquiry_inquiry_messages_path(inquiry_a1), params: { inquiry_message: { body: "正当な返信" } }
      }.to change { inquiry_a1.inquiry_messages.count }.by(1)
      expect(response).to redirect_to(admin_inquiry_path(inquiry_a1))
    end
  end

  describe "代理店グループユーザーは配下代理店の問い合わせのみ" do
    let!(:group_user) { user_with_role("代理店グループ用", agency_group: group_a) }

    before { sign_in_with_otp!(group_user) }

    it "一覧には配下代理店の問い合わせのみ表示される" do
      get admin_inquiries_path
      expect(response.body).to include(inquiry_a1.inquiry_number, inquiry_a2.inquiry_number)
      expect(response.body).not_to include(inquiry_b.inquiry_number)
    end

    it "配下外の代理店の問い合わせ詳細は403" do
      get admin_inquiry_path(inquiry_b)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "問い合わせ作成フロー（admin）" do
    let!(:admin_user) { user_with_role("admin") }

    before { sign_in_with_otp!(admin_user) }

    it "作成時に最初のメッセージが作られ、メール送信ジョブがenqueueされる" do
      expect {
        post admin_inquiries_path, params: {
          inquiry: { order_id: order_a1.id, category: Inquiry::CATEGORY_AFTER, title: "新規問い合わせ",
                     first_message_body: "初回本文" }
        }
      }.to have_enqueued_job(InquiryMessageMailJob)

      inquiry = Inquiry.find_by(title: "新規問い合わせ")
      expect(inquiry).to be_present
      expect(inquiry.inquiry_messages.first.body).to eq("初回本文")
      expect(response).to redirect_to(admin_inquiry_path(inquiry))
    end

    it "返信メッセージ追加でもメール送信ジョブがenqueueされる" do
      expect {
        post admin_inquiry_inquiry_messages_path(inquiry_a1), params: { inquiry_message: { body: "返信" } }
      }.to have_enqueued_job(InquiryMessageMailJob)
    end
  end

  # R6-5: 問い合わせ社内外公開制御（2026-08-20 CEO決定）。is_visible_to_customer=falseの問い合わせは
  # 顧客（Customer/SalesRepresentative）が宛先から除外され、メール・アプリ内通知のいずれも届かない
  # ことを検証する（RecipientResolver#recipients_for_inquiryが両経路(InquiryMessageMailJob/
  # InquiryNotifier)共通の入口であるため、ここを塞げば漏洩経路が塞がることの確認）。
  describe "R6-5: 顧客非公開の問い合わせは顧客・営業担当者へ通知が飛ばない" do
    include ActiveJob::TestHelper

    let!(:admin_user) { user_with_role("admin") }
    let!(:sales_rep) { create(:sales_representative, agency: agency_a1, email: "rep@example.com") }
    let!(:customer_with_mail) { create(:customer, agency: agency_a1, email: "customer-visible-check@example.com") }
    let!(:order_with_mail) do
      create(:order, agency: agency_a1, customer: customer_with_mail, sales_representative: sales_rep)
    end

    before { sign_in_with_otp!(admin_user) }

    it "作成時、顧客・営業担当者はinquiry_message_recipientsに含まれず、代理店は含まれる" do
      post admin_inquiries_path, params: {
        inquiry: { order_id: order_with_mail.id, category: Inquiry::CATEGORY_AFTER, title: "非公開問い合わせ",
                   first_message_body: "社内限定の初回本文", is_visible_to_customer: "0" }
      }

      inquiry = Inquiry.find_by!(title: "非公開問い合わせ")
      expect(inquiry.is_visible_to_customer).to eq(false)

      recipient_types = inquiry.inquiry_messages.first.inquiry_message_recipients.pluck(:recipient_type)
      expect(recipient_types).not_to include("Customer", "SalesRepresentative")
      expect(recipient_types).to include("Agency")
    end

    it "作成時、顧客宛にメールもアプリ内通知も作られない" do
      perform_enqueued_jobs do
        post admin_inquiries_path, params: {
          inquiry: { order_id: order_with_mail.id, category: Inquiry::CATEGORY_AFTER, title: "非公開問い合わせ2",
                     first_message_body: "社内限定の初回本文2", is_visible_to_customer: "0" }
        }
      end

      tos = ActionMailer::Base.deliveries.flat_map(&:to)
      expect(tos).not_to include(customer_with_mail.email, sales_rep.email)
      expect(SystemNotification.where(recipient: customer_with_mail)).to be_empty
    end

    it "既定（is_visible_to_customer未指定=true）では顧客宛にメールが届く" do
      perform_enqueued_jobs do
        post admin_inquiries_path, params: {
          inquiry: { order_id: order_with_mail.id, category: Inquiry::CATEGORY_AFTER, title: "公開問い合わせ",
                     first_message_body: "通常の初回本文" }
        }
      end

      tos = ActionMailer::Base.deliveries.flat_map(&:to)
      expect(tos).to include(customer_with_mail.email)
    end
  end

  # R6-4: 問い合わせ返信テンプレート機能。テンプレート由来かどうかのメタ情報を記録しつつ、
  # 「テンプレート未選択でも新規作成できてしまう」というftlogの弱点を踏まえ、存在しない
  # テンプレートIDを申告する不正なリクエストはサーバー側で弾かれることを確認する。
  describe "R6-4: テンプレートによる返信" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:inquiry_template) { create(:inquiry_template, name: "テスト用FAQテンプレ") }

    before { sign_in_with_otp!(admin_user) }

    it "返信画面にテンプレート選択肢が表示される" do
      get admin_inquiry_path(inquiry_a1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("テスト用FAQテンプレ")
    end

    it "inquiry_template_idを指定して返信すると、テンプレート由来のメタ情報が記録される" do
      expect {
        post admin_inquiry_inquiry_messages_path(inquiry_a1),
             params: { inquiry_message: { body: "テンプレから作成した返信", inquiry_template_id: inquiry_template.id } }
      }.to change { inquiry_a1.inquiry_messages.count }.by(1)

      message = inquiry_a1.inquiry_messages.order(:created_at).last
      expect(message.inquiry_template_id).to eq(inquiry_template.id)
    end

    it "存在しないinquiry_template_id（直叩き等の不正なID）を指定すると保存されず、メッセージも増えない" do
      expect {
        post admin_inquiry_inquiry_messages_path(inquiry_a1),
             params: { inquiry_message: { body: "改ざんされたテンプレID", inquiry_template_id: SecureRandom.uuid } }
      }.not_to change { inquiry_a1.inquiry_messages.count }

      expect(response).to redirect_to(admin_inquiry_path(inquiry_a1))
      follow_redirect!
      expect(response.body).to include("見つかりません")
    end

    it "inquiry_template_idを指定しない通常の返信は従来どおり保存できる" do
      expect {
        post admin_inquiry_inquiry_messages_path(inquiry_a1), params: { inquiry_message: { body: "自由記述の返信" } }
      }.to change { inquiry_a1.inquiry_messages.count }.by(1)

      message = inquiry_a1.inquiry_messages.order(:created_at).last
      expect(message.inquiry_template_id).to be_nil
    end
  end

  # R6-6: 一覧の「完了済みを含む」検索。CompletionStatusFilter(status_klass: InquiryStatus)が
  # コントローラーの#indexへ正しく結線されていることを確認する（単体ロジック自体は
  # spec/services/completion_status_filter_spec.rbで検証済み）。
  describe "R6-6: 完了済みを含む検索" do
    let!(:admin_user) { user_with_role("admin") }
    let!(:completed_inquiry) { create(:inquiry, order: order_a1, category: Inquiry::CATEGORY_AFTER, status: "完了") }

    before { sign_in_with_otp!(admin_user) }

    it "既定（include_completed未指定）では完了系ステータスの問い合わせが一覧から除外される" do
      get admin_inquiries_path
      expect(response.body).not_to include(completed_inquiry.inquiry_number)
      expect(response.body).to include(inquiry_a1.inquiry_number)
    end

    it "include_completed=1を指定すると完了系ステータスの問い合わせも表示される" do
      get admin_inquiries_path, params: { include_completed: "1" }
      expect(response.body).to include(completed_inquiry.inquiry_number)
    end
  end
end
