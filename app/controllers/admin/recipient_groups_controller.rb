# 宛先グループ管理（04 R4タスク3）。メンバー編集はネスト属性（accepts_nested_attributes_for相当を
# 使わず、シンプルにmember_user_idsのcheckbox_group→collection同期で扱う。UI簡素化のため）。
class Admin::RecipientGroupsController < Admin::BaseController
  before_action :set_recipient_group, only: %i[show edit update destroy]

  def index
    @pagy, @recipient_groups = pagy(policy_scope(RecipientGroup).order(:name))
  end

  def show
    authorize @recipient_group
  end

  def new
    @recipient_group = RecipientGroup.new
    authorize @recipient_group
  end

  def edit
    authorize @recipient_group
  end

  def create
    @recipient_group = RecipientGroup.new(recipient_group_params)
    authorize @recipient_group

    if @recipient_group.save
      sync_members!
      redirect_to admin_recipient_group_path(@recipient_group), notice: "宛先グループを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @recipient_group

    if @recipient_group.update(recipient_group_params)
      sync_members!
      redirect_to admin_recipient_group_path(@recipient_group), notice: "宛先グループを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @recipient_group

    if @recipient_group.destroy
      redirect_to admin_recipient_groups_path, notice: "宛先グループを削除しました。"
    else
      redirect_to admin_recipient_group_path(@recipient_group), alert: @recipient_group.errors.full_messages.to_sentence
    end
  end

  private

  def set_recipient_group
    @recipient_group = RecipientGroup.find(params[:id])
  end

  def recipient_group_params
    params.require(:recipient_group).permit(:name, :description, :is_active)
  end

  # member_user_ids[] で選択されたUserの集合になるようRecipientGroupMemberを差し替える
  # （04 R4タスク3。Laravel実装はUser/ProductionCompanyの2型対応だが、管理画面UIはR4スコープでは
  # Userのみを対象にする。ProductionCompanyのメンバー登録はAPI/コンソール操作で足りる想定＝過剰実装を避ける）。
  def sync_members!
    ids = Array(params[:member_user_ids]).compact_blank
    @recipient_group.recipient_group_members.where(recipient_type: "User").destroy_all
    ids.each { |id| @recipient_group.recipient_group_members.create!(recipient_type: "User", recipient_id: id) }
  end
end
