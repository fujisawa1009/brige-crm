# 店舗管理（04 R2タスク1・8）。customers配下のネストリソース（/admin/customers/:customer_id/stores）。
# StorePolicyはcustomer経由でagencyスコープを解決する（agency_idを直接持たないため）。
class Admin::StoresController < Admin::BaseController
  before_action :set_customer
  before_action :set_store, only: %i[show edit update destroy]

  def index
    # ページネーション追加（CEO指示 2026-08-20 タスク6）。多店舗の顧客で行数が伸びるため。
    # store_name は一意でないので、ページ送りの順序を安定させる第2キーに id を添える。
    @pagy, @stores = pagy(policy_scope(Store).where(customer: @customer).order(:store_name, :id))
  end

  def show
    authorize @store
  end

  def new
    @store = @customer.stores.new
    authorize @store
  end

  def edit
    authorize @store
  end

  def create
    @store = @customer.stores.new(store_params)
    authorize @store

    if @store.save
      redirect_to admin_customer_store_path(@customer, @store), notice: "店舗を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @store

    if @store.update(store_params)
      redirect_to admin_customer_store_path(@customer, @store), notice: "店舗を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @store

    if @store.destroy
      redirect_to admin_customer_stores_path(@customer), notice: "店舗を削除しました。"
    else
      redirect_to admin_customer_store_path(@customer, @store), alert: @store.errors.full_messages.to_sentence
    end
  end

  private

  def set_customer
    # 顧客そのものへのアクセス可否をここで先にチェックする（他代理店の顧客IDを直接指定して
    # 店舗一覧に到達するのを防ぐ。StorePolicy側の判定はcustomer_idが正しい前提で動くため、
    # customer自体のPunditチェックが必須の二重防御になる）。
    @customer = Customer.find(params[:customer_id])
    authorize @customer, :show?
  end

  def set_store
    @store = @customer.stores.find(params[:id])
  end

  def store_params
    params.require(:store).permit(
      :store_code, :store_name, :store_name_kana, :postal_code, :prefecture, :city, :town,
      :address_detail, :phone_number, :fax_number, :business_hours_1, :business_hours_2,
      :regular_holiday, :is_active
    )
  end
end
