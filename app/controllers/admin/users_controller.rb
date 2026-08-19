# 管理画面ユーザー管理（04 R1）。作成は staff（admin/実務運用者）のみ（UserPolicy参照。初期パスワード
# 発行を伴うためこのコントローラでのみ password/password_confirmation を扱う）。更新は自代理店・
# 配下代理店のユーザーも自スコープ内のサブアカウントに対して可能だが、agency_id/agency_group_id
# （所属の付け替え）は staff以外のパラメータから除去する（権限昇格防止）。パスワード変更自体は
# 既存の users/registrations（セルフサービス）に委ね、このCRUDでは扱わない。
class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show, :edit, :update, :destroy ]

  # 一覧は顧客一覧（Admin::CustomersController#index）と同じ形: policy_scope + pagy + 簡易検索/絞り込み。
  # 代理店/代理店グループの絞り込み選択肢はpolicy_scopeで絞る（2026-08-19認可監査でCustomer側の
  # 選択肢が代理店スコープを迂回していた不具合が見つかっているため、同じ穴をここでも作らない）。
  def index
    scope = policy_scope(User).includes(:agency, :agency_group, :system_roles).order(:email)
    scope = scope.where("users.name ILIKE :q OR users.email ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

    case params[:account_type]
    when "agency"       then scope = scope.where.not(agency_id: nil)
    when "agency_group" then scope = scope.where.not(agency_group_id: nil)
    when "staff"        then scope = scope.where(agency_id: nil, agency_group_id: nil)
    end

    scope = scope.where(agency_id: params[:agency_id]) if params[:agency_id].present?
    scope = scope.where(agency_group_id: params[:agency_group_id]) if params[:agency_group_id].present?
    scope = scope.where(is_active: params[:is_active]) if params[:is_active].present?
    if params[:role_id].present?
      scope = scope.joins(:system_roles).where(system_roles: { id: params[:role_id] }).distinct
    end

    @pagy, @users = pagy(scope)
    @agency_groups = policy_scope(AgencyGroup).order(:name)
    @agencies = policy_scope(Agency).order(:name)
    @roles = SystemRole.order(Arel.sql("COALESCE(position, 99999), name ASC"))
  end

  def show
    authorize @user
  end

  def new
    @user = User.new
    authorize @user
  end

  def edit
    authorize @user
  end

  def create
    @user = User.new(user_create_params)
    authorize @user

    if @user.save
      redirect_to admin_user_path(@user), notice: "ユーザーを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @user
    permitted = strip_ownership_params!(user_update_params, :agency_id, :agency_group_id, policy_record: @user)

    if @user.update(permitted)
      redirect_to admin_user_path(@user), notice: "ユーザーを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @user

    if @user.destroy
      redirect_to admin_users_path, notice: "ユーザーを削除しました。"
    else
      redirect_to admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
    end
  end

  # CSV一括アップロード（04 R1タスク5）。作成系のためUserPolicy#create?（staff_scope?）で認可する。
  def import
    authorize User, :create?
  end

  def import_upload
    authorize User, :create?

    file = params[:csv_file]
    if file.blank?
      redirect_to import_admin_users_path, alert: "CSVファイルを選択してください。"
      return
    end

    UserCsvImportJob.perform_later(file.read, requested_by_user_id: current_user.id)
    redirect_to admin_users_path, notice: "CSV取込を開始しました（非同期処理）。完了後、一覧をご確認ください。"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_create_params
    params.require(:user).permit(
      :name, :email, :password, :password_confirmation, :agency_group_id, :agency_id, :is_active
    )
  end

  def user_update_params
    params.require(:user).permit(:name, :email, :is_active, :agency_group_id, :agency_id)
  end
end
