# 選択肢値マスタ管理（04 R2タスク4）。parent_idで自己参照ツリーを表現する。
class Admin::OptionValuesController < Admin::BaseController
  before_action :set_option_value, only: %i[show edit update destroy]

  def index
    @pagy, @option_values = pagy(policy_scope(OptionValue).order(:option_group_id, :sort_order))
  end

  def show
    authorize @option_value
  end

  def new
    @option_value = OptionValue.new
    authorize @option_value
  end

  def edit
    authorize @option_value
  end

  def create
    @option_value = OptionValue.new(option_value_params)
    authorize @option_value

    if @option_value.save
      redirect_to admin_option_value_path(@option_value), notice: "選択肢を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @option_value

    if @option_value.update(option_value_params)
      redirect_to admin_option_value_path(@option_value), notice: "選択肢を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @option_value

    if @option_value.destroy
      redirect_to admin_option_values_path, notice: "選択肢を削除しました。"
    else
      redirect_to admin_option_value_path(@option_value), alert: @option_value.errors.full_messages.to_sentence
    end
  end

  private

  def set_option_value
    @option_value = OptionValue.find(params[:id])
  end

  def option_value_params
    params.require(:option_value).permit(:option_group_id, :parent_id, :value, :label, :depth, :sort_order,
                                          :is_active)
  end
end
