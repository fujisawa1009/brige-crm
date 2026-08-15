# 選択肢グループマスタ管理（04 R2タスク4）。
class Admin::OptionGroupsController < Admin::BaseController
  before_action :set_option_group, only: %i[show edit update destroy]

  def index
    @pagy, @option_groups = pagy(policy_scope(OptionGroup).order(:sort_order))
  end

  def show
    authorize @option_group
  end

  def new
    @option_group = OptionGroup.new
    authorize @option_group
  end

  def edit
    authorize @option_group
  end

  def create
    @option_group = OptionGroup.new(option_group_params)
    authorize @option_group

    if @option_group.save
      redirect_to admin_option_group_path(@option_group), notice: "選択肢グループを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @option_group

    if @option_group.update(option_group_params)
      redirect_to admin_option_group_path(@option_group), notice: "選択肢グループを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @option_group

    if @option_group.destroy
      redirect_to admin_option_groups_path, notice: "選択肢グループを削除しました。"
    else
      redirect_to admin_option_group_path(@option_group), alert: @option_group.errors.full_messages.to_sentence
    end
  end

  private

  def set_option_group
    @option_group = OptionGroup.find(params[:id])
  end

  def option_group_params
    params.require(:option_group).permit(:key, :label, :description, :sort_order, :is_active)
  end
end
