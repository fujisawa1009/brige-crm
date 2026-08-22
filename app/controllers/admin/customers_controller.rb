# 顧客管理（04 R2タスク1・7・8）。一覧はPundit policy_scope（代理店=自代理店のみ・グループ=配下のみ）+
# pagyページネーション + 検索（CustomerSearch。CEO指示 2026-08-20 で旧ジャスミン相当の9条件へ拡充）。
# 作成はstaff限定（AgencyScoped既定。CustomerPolicy参照）、更新は自代理店・配下代理店内の自己編集を許可。
class Admin::CustomersController < Admin::BaseController
  before_action :set_customer, only: %i[show edit update destroy]
  helper_method :customer_status_label, :customer_search_params

  def index
    scope = policy_scope(Customer).includes(:agency, :sales_representative).order(*default_order)
    # 検索条件そのものには参照制御を持たせない。policy_scope を通したスコープを渡すことで、
    # 代理店ユーザーが他代理店の代理店コード/名を直接入力しても結果には出ない（2重の防御ではなく
    # 「絞り込みは常にpolicy_scopeの内側で行う」という一方向の設計）。
    @pagy, @customers = pagy(CustomerSearch.new(scope, customer_search_params).results)
  end

  def show
    authorize @customer
  end

  def new
    @customer = Customer.new
    authorize @customer
    load_select_options
  end

  def edit
    authorize @customer
    load_select_options
  end

  def create
    @customer = Customer.new(customer_params)
    authorize @customer

    if @customer.save
      redirect_to admin_customer_path(@customer), notice: "顧客を作成しました。"
    else
      load_select_options
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @customer
    permitted = strip_ownership_params!(customer_params, :agency_id, policy_record: @customer)

    if @customer.update(permitted)
      redirect_to admin_customer_path(@customer), notice: "顧客を更新しました。"
    else
      load_select_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer

    if @customer.destroy
      redirect_to admin_customers_path, notice: "顧客を削除しました。"
    else
      redirect_to admin_customer_path(@customer), alert: @customer.errors.full_messages.to_sentence
    end
  end

  # CSV非同期エクスポート（04 R2タスク7）。UserCsvImportJobのimport/import_uploadと対の設計。
  def export
    authorize Customer, :index?

    csv_export = CsvExport.create!(resource_type: "Customer", requested_by: current_user, status: "pending")
    CsvExportJob.perform_later(csv_export.id)
    redirect_to admin_csv_exports_path, notice: "CSVエクスポートを開始しました（非同期処理）。完了後、一覧からダウンロードできます。"
  end

  private

  # 一覧の既定の並び順（CEO指示 2026-08-20 タスク4）。旧ジャスミン（Laravel版）は
  # `applied_at DESC` 固定で、Rails版の `customer_number ASC` は旧と非互換だったため旧に合わせる。
  #
  # - NULL の扱いは **NULLS LAST**（お申込日が未入力の顧客は末尾）。PostgreSQL の DESC は
  #   既定が NULLS FIRST のため、指定しないと未入力の顧客が一覧の先頭を占めてしまう。
  #   「新しい順」の意図として日付不明を最新扱いするのは不自然であり、旧実装（MySQL）の
  #   `DESC` も NULL を末尾に置くため、挙動としても旧と一致する。
  # - 第2キーに customer_number を添える。applied_at は日付（時刻を持たない）ため同値が
  #   多発し、第2キーが無いとページ送りのたびに順序がぶれて同じ行が2度出たり消えたりする。
  def default_order
    [ Customer.arel_table[:applied_at].desc.nulls_last, :customer_number ]
  end

  # 検索フォームの値。ビューからも参照する（ページ送りをまたいだ保持は pagy_url_for が
  # request.GET をそのまま引き継ぐことで成立する）。
  def customer_search_params
    @customer_search_params ||= params.permit(*CustomerSearch::PERMITTED_KEYS).to_h.symbolize_keys
  end

  def set_customer
    @customer = Customer.find(params[:id])
  end

  # Customer#statusはCustomerStatus.code（英字コード）を持つのみで表示ラベルを持たないため、
  # 一覧・詳細で日本語ラベルに変換する。コード→ラベルの対応は小さいマスタなので1クエリで全件
  # メモ化し、行数分のN+1を避ける。
  def customer_status_label(code)
    @customer_status_labels ||= CustomerStatus.pluck(:code, :label).to_h
    @customer_status_labels.fetch(code, code)
  end

  # フォームのcollection_selectが代理店スコープを迂回していた穴の是正（2026-08-19 認可監査で発見）。
  # sales_representative_idがビュー内で直接SalesRepresentative.orderを呼んでおり、他代理店の営業担当者名が
  # 選択肢に混入していた。agency_idはビュー側でstaff_scope?時のみ表示するため対象外。
  def load_select_options
    @sales_representatives = policy_scope(SalesRepresentative).order(:name)
  end

  def customer_params
    params.require(:customer).permit(
      :agency_id, :sales_representative_id, :name, :status, :applied_at, :contracted_at,
      :applicant_type, :agency_customer_code, :inventory_type, :contractor_name_kana,
      :representative_name, :representative_name_kana,
      :contact_name, :contact_name_kana, :contact_title, :contact_dept_phone,
      :contact2_name, :contact2_name_kana, :contact2_title, :contact2_dept_phone,
      :postal_code, :prefecture, :city, :town, :address_detail,
      :phone, :fax_number, :mobile_phone, :mobile_contact_person, :email,
      :industry, :industry_sub, :years_in_business, :num_employees, :num_offices,
      :consolidated_billing, :invoice_destination, :invoice_name, :invoice_name_kana,
      :invoice_postal_code, :invoice_address, :invoice_phone, :invoice_other_phone,
      :confirm_staff_code, :confirm_staff_name, :appointer_code, :appointer_name,
      :lbc_code, :sales_mgmt_customer_code, :netmove_member_id, :netmove_registered_at,
      :sms_mobile_number
    )
  end
end
