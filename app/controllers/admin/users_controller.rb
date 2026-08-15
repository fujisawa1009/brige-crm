# 管理画面ユーザー管理（04 R1）。作成は staff（admin/実務運用者）のみ（UserPolicy参照。初期パスワード
# 発行を伴うためこのコントローラでのみ password/password_confirmation を扱う）。更新は自代理店・
# 配下代理店のユーザーも自スコープ内のサブアカウントに対して可能だが、agency_id/agency_group_id
# （所属の付け替え）は staff以外のパラメータから除去する（権限昇格防止）。パスワード変更自体は
# 既存の users/registrations（セルフサービス）に委ね、このCRUDでは扱わない。
class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show, :edit, :update, :destroy ]

  def index
    @users = policy_scope(User).order(:email)
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
