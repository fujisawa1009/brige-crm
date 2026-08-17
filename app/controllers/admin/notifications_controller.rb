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
    load_notification_templates
  end

  def edit
    authorize @notification
    load_notification_templates
  end

  def create
    @notification = Notification.new(notification_params)
    @notification.status = Notification::STATUS_DRAFT
    authorize @notification
    apply_template_defaults

    if @notification.save
      redirect_to admin_notification_path(@notification), notice: "通知を下書き保存しました。"
    else
      load_notification_templates
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @notification
    @notification.assign_attributes(notification_params)
    apply_template_defaults

    if @notification.save
      redirect_to admin_notification_path(@notification), notice: "通知を更新しました。"
    else
      load_notification_templates
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
    params.require(:notification).permit(:title, :subject, :body, :target_type, :notification_template_id, filter_params: {})
  end

  # フォームで選択できるテンプレート（04 R4タスク2）。notification / common タイプのみ＝通知作成に
  # 使える集合に限定する（inquiry 専用テンプレートは一斉通知の対象外）。NotificationTemplate に
  # is_active 列は存在しないため template_type で絞る（当初指示の is_active 前提は現行スキーマと不一致）。
  def load_notification_templates
    @notification_templates = NotificationTemplate
      .where(template_type: [ NotificationTemplate::TYPE_NOTIFICATION, NotificationTemplate::TYPE_COMMON ])
      .order(:name)
  end

  # テンプレート選択時のサーバ側フォールバック（04 R4タスク2）。通常は Stimulus が件名・本文を自動入力するが、
  # JS無効時でも件名/本文が空ならテンプレートの値をコピーする（ライブ参照ではなくコピー＝以後は編集可能・
  # 送信済み通知はテンプレート編集の影響を受けない）。既に入力済みの値は尊重して上書きしない。
  def apply_template_defaults
    template = @notification.notification_template
    return unless template

    @notification.subject = template.subject if @notification.subject.blank?
    @notification.body    = template.body    if @notification.body.blank?
  end
end
