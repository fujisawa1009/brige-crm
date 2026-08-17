# 一斉通知管理（04 R4タスク3）。createはdraftのまま保存（本文/フィルタの下書き）、
# scheduleアクションでSolid Queueへ投入する（即時=scheduled_at未指定→Notification#deliver_now_via_job!、
# 予約=Notification#schedule!）という2段階（Laravel現行のdraft→scheduled/sending→sent遷移踏襲）。
class Admin::NotificationsController < Admin::BaseController
  before_action :set_notification, only: %i[show edit update destroy schedule]

  def index
    @pagy, @notifications = pagy(policy_scope(Notification).order(created_at: :desc))
  end

  def show
    authorize @notification
  end

  def new
    @notification = Notification.new(target_type: Notification::TARGET_AGENCY, status: Notification::STATUS_DRAFT)
    authorize @notification
  end

  def edit
    authorize @notification
  end

  def create
    @notification = Notification.new(notification_params)
    @notification.status = Notification::STATUS_DRAFT
    authorize @notification

    if @notification.save
      redirect_to admin_notification_path(@notification), notice: "通知を下書き保存しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @notification

    if @notification.update(notification_params)
      redirect_to admin_notification_path(@notification), notice: "通知を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @notification

    if @notification.destroy
      redirect_to admin_notifications_path, notice: "通知を削除しました。"
    else
      redirect_to admin_notification_path(@notification), alert: @notification.errors.full_messages.to_sentence
    end
  end

  # 送信登録（即時 or 予約）。04 R4本文「スケジュール送信はSolid Queueのdelayed jobで実装」。
  def schedule
    authorize @notification, :update?

    if params[:scheduled_at].present?
      @notification.schedule!(params[:scheduled_at])
      redirect_to admin_notification_path(@notification), notice: "送信を予約しました。"
    else
      @notification.deliver_now_via_job!
      redirect_to admin_notification_path(@notification), notice: "送信を開始しました。"
    end
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def notification_params
    params.require(:notification).permit(:title, :subject, :body, :target_type, filter_params: {})
  end
end
