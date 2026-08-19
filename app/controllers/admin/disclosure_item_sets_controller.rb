# 重説項目セットの版管理（04 R5-13・contract-confirmation-docs.md §3-1）。
# form_templates_controllerと同じ「1画面のネスト属性フォームでまとめて編集」パターン。
class Admin::DisclosureItemSetsController < Admin::BaseController
  before_action :set_disclosure_item_set, only: %i[show edit update destroy]

  def index
    @disclosure_item_sets = policy_scope(DisclosureItemSet).order(version: :desc)
  end

  def show
    authorize @disclosure_item_set
  end

  def new
    @disclosure_item_set = DisclosureItemSet.new
    @disclosure_item_set.disclosure_items.build
    authorize @disclosure_item_set
  end

  def edit
    authorize @disclosure_item_set
  end

  def create
    @disclosure_item_set = DisclosureItemSet.new(disclosure_item_set_params)
    authorize @disclosure_item_set

    if @disclosure_item_set.save
      redirect_to admin_disclosure_item_set_path(@disclosure_item_set), notice: "重説項目セットを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @disclosure_item_set

    if @disclosure_item_set.update(disclosure_item_set_params)
      redirect_to admin_disclosure_item_set_path(@disclosure_item_set), notice: "重説項目セットを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @disclosure_item_set

    if @disclosure_item_set.destroy
      redirect_to admin_disclosure_item_sets_path, notice: "重説項目セットを削除しました。"
    else
      redirect_to admin_disclosure_item_set_path(@disclosure_item_set),
                  alert: @disclosure_item_set.errors.full_messages.to_sentence
    end
  end

  private

  def set_disclosure_item_set
    @disclosure_item_set = DisclosureItemSet.find(params[:id])
  end

  def disclosure_item_set_params
    params.require(:disclosure_item_set).permit(
      :version, :effective_from,
      disclosure_items_attributes: %i[id sort_order title body is_required _destroy]
    )
  end
end
