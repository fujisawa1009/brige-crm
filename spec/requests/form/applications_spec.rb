require "rails_helper"

# 04 R3タスク4・5: 動的マルチステップ申込と申込完了トランザクション。
# R3完了条件（04-rails-implementation-plan.md）: 「営業担当者ログイン（代理店CD+営業CD+OTP）→
# 動的マルチステップ→完了、のrequest spec」「申込トランザクションのrequest spec必須。正常系・異常系
# （バリデーション失敗時にトランザクション全体がロールバックされ、Customer/Store/Orderが中途半端に
# 作られないこと）の両方をテストすること」（Laravel側の未カバー教訓=01§7 T-1を踏まえた要求）。
RSpec.describe "Form::Applications", type: :request, seed_status_catalog: true, seed_permission_catalog: true do
  let!(:agency_group) { create(:agency_group) }
  let!(:agency) { create(:agency, agency_group: agency_group) }
  let!(:sales_representative) { create(:sales_representative, agency: agency, email: "rep@example.com") }
  let!(:product) { create(:product) }
  let!(:option) { create(:product_option, product: product) }
  let!(:form_template) { build_two_step_form_template(product: product, options: [ option ]) }

  before do
    AgencyProduct.create!(agency: agency, product: product)
    create(:contract_condition, agency: agency, effective_from: 1.year.ago.to_date, effective_until: nil)
    sign_in_sales_representative_with_otp!(sales_representative)
  end

  describe "商材選択（営業担当者ログイン→動的マルチステップの起点）" do
    it "販売許可された商材のみ一覧に表示される" do
      other_product = create(:product) # AgencyProduct無し=販売許可されていない

      get form_new_application_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
      expect(response.body).not_to include(other_product.name)
    end

    it "商材を選ぶとApplicationが作成されステップ1へ遷移する" do
      expect do
        post form_applications_path, params: { product_id: product.id }
      end.to change(Application, :count).by(1)

      application = Application.last
      expect(application.token.length).to eq(64)
      expect(response).to redirect_to(form_application_step_path(token: application.token, step_number: 1))
    end

    it "販売許可されていない商材IDを直接指定しても申込を開始できない" do
      not_allowed = create(:product)

      expect do
        post form_applications_path, params: { product_id: not_allowed.id }
      end.not_to change(Application, :count)
      expect(response).to redirect_to(form_new_application_path)
    end
  end

  describe "動的マルチステップ" do
    let!(:application) do
      post form_applications_path, params: { product_id: product.id }
      Application.last
    end

    it "必須項目が空だと422になり、ステップは進まずform_dataも更新されない" do
      patch form_update_application_step_path(token: application.token, step_number: 1),
            params: { answers: { customer_name: "", customer_email: "", store_name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(application.reload.current_step_number).to eq(1)
      expect(application.form_data).to eq({})
    end

    it "有効な入力ならステップ2へ進み、回答がform_dataに蓄積される" do
      patch form_update_application_step_path(token: application.token, step_number: 1),
            params: { answers: { customer_name: "山田太郎", customer_email: "yamada@example.com", store_name: "本店" } }

      expect(response).to redirect_to(form_application_step_path(token: application.token, step_number: 2))
      application.reload
      expect(application.form_data["customer_name"]).to eq("山田太郎")
      expect(application.current_step_number).to eq(2)
    end

    it "最終ステップの入力後は確認画面へ遷移する" do
      patch form_update_application_step_path(token: application.token, step_number: 1),
            params: { answers: { customer_name: "山田太郎", customer_email: "yamada@example.com", store_name: "本店" } }
      patch form_update_application_step_path(token: application.token, step_number: 2),
            params: { answers: { order_remarks: "至急対応希望", order_options: [ option.id ] } }

      expect(response).to redirect_to(form_application_complete_path(token: application.token))
    end

    it "商材に紐づかないオプションIDを送っても拒否される（他商材オプションの紛れ込み対策）" do
      other_product_option = create(:product_option) # 別商材のオプション

      patch form_update_application_step_path(token: application.token, step_number: 2),
            params: { answers: { order_remarks: "", order_options: [ other_product_option.id ] } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "他の営業担当者のtokenにはアクセスできない（IDOR対策）" do
      other_rep = create(:sales_representative, agency: agency, email: "other@example.com")
      other_application = create(:application, sales_representative: other_rep, agency: agency, product: product)

      get form_application_step_path(token: other_application.token, step_number: 1)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "申込完了トランザクション" do
    let!(:staff_user) { user_with_role("実務運用者", email: "staff@example.com") }
    let!(:application) do
      post form_applications_path, params: { product_id: product.id }
      Application.last
    end

    before do
      patch form_update_application_step_path(token: application.token, step_number: 1),
            params: { answers: { customer_name: "山田太郎", customer_email: "yamada@example.com", store_name: "本店" } }
      patch form_update_application_step_path(token: application.token, step_number: 2),
            params: { answers: { order_remarks: "至急対応希望", order_options: [ option.id ] } }
    end

    it "確認画面に入力内容が表示される" do
      get form_application_complete_path(token: application.token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("山田太郎", "至急対応希望")
    end

    describe "正常系" do
      it "Customer+Store+Order+OrderOptionが1件ずつ生成され、確認メール・スタッフ通知・監査ログが記録される" do
        expect do
          perform_enqueued_jobs do
            post form_submit_application_path(token: application.token)
          end
        end.to change(Customer, :count).by(1)
          .and change(Store, :count).by(1)
          .and change(Order, :count).by(1)
          .and change(OrderOption, :count).by(1)

        application.reload
        expect(application).to be_completed
        expect(application.customer.name).to eq("山田太郎")
        expect(application.store.store_name).to eq("本店")
        expect(application.order.remarks).to eq("至急対応希望")
        expect(application.order.product_options).to contain_exactly(option)
        expect(application.order.contract_condition).to eq(agency.current_contract_condition)

        recipients = ActionMailer::Base.deliveries.flat_map(&:to)
        expect(recipients).to include("yamada@example.com", "staff@example.com")

        audit = AuditLog.find_by(resource_type: "Application", action: "application_completed")
        expect(audit).to be_present
        expect(audit.user_id).to eq(sales_representative.id)
        expect(audit.user_type).to eq("SalesRepresentative")
      end

      # R3レビュー指摘: form_data(jsonb・暗号化なし)にはSNS認証情報等の機密情報が入りうるため、
      # 各カラムへ転記済みの完了後は平文のまま残さずクリアする
      # （app/services/form/application_submission_service.rb参照）。
      it "申込完了後はApplication#form_dataが空になる" do
        post form_submit_application_path(token: application.token)

        expect(application.reload.form_data).to eq({})
      end

      it "完了後に再送信すると重複してレコードが作られず完了画面へ遷移する" do
        post form_submit_application_path(token: application.token)

        expect do
          post form_submit_application_path(token: application.token)
        end.not_to change(Order, :count)
        expect(response).to redirect_to(form_application_complete_path(token: application.token))
      end
    end

    describe "異常系（ロールバック）" do
      it "代理店の現行契約条件が無い場合はCustomer/Store/Orderが1件も作られない" do
        ContractCondition.where(agency: agency).update_all(effective_until: Date.current)

        expect do
          post form_submit_application_path(token: application.token)
        end.to change(Customer, :count).by(0)
          .and change(Store, :count).by(0)
          .and change(Order, :count).by(0)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(application.reload).not_to be_completed
      end

      it "Order側のバリデーションが失敗した場合、先に成功していたCustomer/Storeの保存もロールバックされる" do
        # order_statusesから既定コードを削除し（is_system行のためdestroyでは消せず、delete_allでDB行だけ
        # 消す）、Order#status_must_exist_in_order_statusesを失敗させる。Customer/Storeは正常に保存できる
        # 状態のまま最後のOrder#save!だけが失敗する状況を作ることで、
        # ActiveRecord::Base.transactionが1つのトランザクションとして機能していることを検証する。
        OrderStatus.where(code: OrderStatus::CODE_ORDERED).delete_all

        expect do
          post form_submit_application_path(token: application.token)
        end.to change(Customer, :count).by(0)
          .and change(Store, :count).by(0)
          .and change(Order, :count).by(0)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(application.reload).not_to be_completed
        expect(application.customer_id).to be_nil
      end
    end
  end
end
