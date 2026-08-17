# 種別×ステータス→宛先ルーティング管理（04 R4タスク2・決定D-11。board-implementation-options.md §5-1）。
class Admin::InquiryRecipientRoutesController < Admin::BaseController
  before_action :set_route, only: %i[show edit update destroy]

  def index
    scope = policy_scope(InquiryRecipientRoute).includes(:recipient_group).order(:category, :status_code)
    scope = scope.where(category: params[:category]) if params[:category].present?
    @pagy, @inquiry_recipient_routes = pagy(scope)
  end

  def show
    authorize @inquiry_recipient_route
  end

  def new
    @inquiry_recipient_route = InquiryRecipientRoute.new
    authorize @inquiry_recipient_route
  end

  def edit
    authorize @inquiry_recipient_route
  end

  def create
    @inquiry_recipient_route = InquiryRecipientRoute.new(inquiry_recipient_route_params)
    authorize @inquiry_recipient_route

    if @inquiry_recipient_route.save
      redirect_to admin_inquiry_recipient_route_path(@inquiry_recipient_route), notice: "ルーティングを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @inquiry_recipient_route

    if @inquiry_recipient_route.update(inquiry_recipient_route_params)
      redirect_to admin_inquiry_recipient_route_path(@inquiry_recipient_route), notice: "ルーティングを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @inquiry_recipient_route

    if @inquiry_recipient_route.destroy
      redirect_to admin_inquiry_recipient_routes_path, notice: "ルーティングを削除しました。"
    else
      redirect_to admin_inquiry_recipient_route_path(@inquiry_recipient_route),
                  alert: @inquiry_recipient_route.errors.full_messages.to_sentence
    end
  end

  private

  def set_route
    @inquiry_recipient_route = InquiryRecipientRoute.find(params[:id])
  end

  def inquiry_recipient_route_params
    params.require(:inquiry_recipient_route).permit(:category, :status_code, :recipient_group_id)
  end
end
