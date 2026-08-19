# 案件管理（04 R2タスク1・7・8・9）。R2完了条件の中核: policy_scopeで代理店ユーザは自代理店の
# 案件のみ、代理店グループユーザは配下代理店の案件のみに絞られる（OrderPolicy参照）。
class Admin::OrdersController < Admin::BaseController
  before_action :set_order, only: %i[show edit update destroy]

  def index
    scope = policy_scope(Order).includes(:customer, :agency).order(order_number: :desc)
    scope = scope.where("order_number ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

    if params[:status].present?
      # ステータスを明示指定した場合はそれを優先する（例: 「16:完了」を選んだのに完了系除外の
      # 既定フィルタと衝突して0件になる、という事故を避けるため。「完了済みを含む」チェックボックスは
      # あくまでデフォルト表示の切り替えであり、明示的な絞り込みより弱い）。
      scope = scope.where(status: params[:status])
    else
      # R6-6: 既定で完了/終了系ステータス（OrderStatus#is_completed）を除外し、
      # include_completed=1（一覧のチェックボックス）で全件表示に切り替える。
      scope = CompletionStatusFilter.new(status_klass: OrderStatus).apply(scope, include_completed: params[:include_completed])
    end

    @pagy, @orders = pagy(scope)
  end

  def show
    authorize @order
  end

  def new
    @order = Order.new
    authorize @order
    load_select_options
  end

  def edit
    authorize @order
    load_select_options
  end

  def create
    @order = Order.new(order_params)
    authorize @order

    if @order.save
      redirect_to admin_order_path(@order), notice: "案件を作成しました。"
    else
      load_select_options
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @order
    # customer_id/store_idもagency_idと同じ権限昇格経路になるため除去対象に含める（04 R2追補バグ修正。
    # 詳細はAdmin::BaseController#strip_ownership_params!のコメント参照）。
    permitted = strip_ownership_params!(order_params, :agency_id, :customer_id, :store_id, policy_record: @order)

    if @order.update(permitted)
      redirect_to admin_order_path(@order), notice: "案件を更新しました。"
    else
      load_select_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @order

    if @order.destroy
      redirect_to admin_orders_path, notice: "案件を削除しました。"
    else
      redirect_to admin_order_path(@order), alert: @order.errors.full_messages.to_sentence
    end
  end

  def export
    authorize Order, :index?

    csv_export = CsvExport.create!(resource_type: "Order", requested_by: current_user, status: "pending")
    CsvExportJob.perform_later(csv_export.id)
    redirect_to admin_csv_exports_path, notice: "CSVエクスポートを開始しました（非同期処理）。完了後、一覧からダウンロードできます。"
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  # フォームのcollection_selectが代理店スコープを迂回して全件を露出していた穴の是正
  # （2026-08-19 認可監査で発見。customer_id/store_id/contract_condition_id/sales_representative_idの
  # 4フィールドがビュー内で直接Model.orderを呼んでおり、他代理店の顧客・店舗・契約条件・営業担当者名が
  # 選択肢に混入していた）。agency_idはビュー側でstaff_scope?時のみ表示するため対象外。
  def load_select_options
    @customers = policy_scope(Customer).order(:customer_number)
    @stores = policy_scope(Store).order(:store_name)
    @contract_conditions = policy_scope(ContractCondition).order(:name)
    @sales_representatives = policy_scope(SalesRepresentative).order(:name)
  end

  # Column.md §10準拠の全フィールド（billing_passwordはPII暗号化対象だが、代理店の請求パスワードの
  # 入力・更新自体は業務上必要な操作のためparamsの許可対象からは外さない。表示側での扱いは
  # app/views/admin/orders/_form.html.erbのpassword_field相当で行う）。
  def order_params
    params.require(:order).permit(
      :customer_id, :store_id, :sales_representative_id, :agency_id, :contract_condition_id, :serial_id,
      :plan_id, :product_initial_fee_id, :payment_method, :plus_applied,
      :status,
      :ordered_at, :contract_start_date, :contract_sent_at, :issued_at, :account_issued_at,
      :work_completed_at, :accounting_month, :bridge_accounting_month, :payment_collected_at,
      :payment_doc_confirmed_at, :cancelled_at, :terminated_at, :termination_reason,
      :confirm_call_staff_name, :confirm_call_notes, :confirm_call_preferred_date, :confirm_call_time,
      :confirm_call_contact_name, :confirm_call_remarks,
      :inspection_call_ng_time, :inspection_call_history, :inspection_call_completed_at,
      :elderly_consent, :elderly_consent_collected_at, :business_auth_doc, :business_auth_doc_collected_at,
      :business_proof, :consent_status, :consent_rep_age, :consent_contact_age, :paper_address_note,
      :sales_mgmt_slip_number, :factor_notes, :bundled_billing, :bundle_target_order_number,
      :finance_division, :finance_installer, :finance_postal_code, :finance_prefecture, :finance_city,
      :finance_town, :finance_address_detail, :finance_building, :finance_phone,
      :member_id, :billing_password, :meo_mgmt_number, :toss_up_code,
      :bridge_migration, :bridge_migration_order_number, :bridge_agency_name, :bridge_sales_rep_name,
      :citation_applied, :citation_count, :citation_existing_serial, :domestic_citation_plan, :citation_plan,
      :s_plan_cms, :owlet_cms, :onerank_cms, :external_link_applied, :external_link_count, :external_link_type,
      :gbp_multilingual, :language_selection, :meo_existing_serial, :infobiz_applied, :meo_premium_applied,
      :google_ads_applied, :google_ads_count, :google_review_display, :review_heading, :reservation_system,
      :portal_site_applied, :remarks, :shared_notes
    )
  end
end
