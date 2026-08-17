# 問い合わせ管理（04 R4タスク1・2）。作成時に最初のInquiryMessage（本文）も一緒に受け取り、
# RecipientResolverで宛先を自動解決してInquiryMessageRecipientへ書き込むところまでを1トランザクションで
# 行う（画面上「問い合わせを起票する」＝必ず本文付きで始まる、というLaravel現行の業務フローに合わせる）。
class Admin::InquiriesController < Admin::BaseController
  before_action :set_inquiry, only: %i[show]

  def index
    scope = policy_scope(Inquiry).includes(:order).order(created_at: :desc)
    scope = scope.for_category(params[:category]) if params[:category].present?
    @pagy, @inquiries = pagy(scope)
  end

  def show
    authorize @inquiry
    @inquiry_messages = @inquiry.inquiry_messages.includes(:inquiry_message_recipients)
    @inquiry_message = InquiryMessage.new
  end

  def new
    @inquiry = Inquiry.new(order_id: params[:order_id])
    authorize @inquiry
  end

  def create
    @inquiry = Inquiry.new(inquiry_params)
    authorize @inquiry

    first_message = nil
    ActiveRecord::Base.transaction do
      @inquiry.save!
      first_message = @inquiry.inquiry_messages.create!(body: params.dig(:inquiry, :first_message_body))
      first_message.assign_recipients!(RecipientResolver.recipients_for_inquiry(@inquiry))
      InquiryNotifier.notify_message_created(first_message)
    end

    # メール通知はコミット確定後にenqueueする（トランザクション未コミット中にジョブが走り、
    # レコード未発見で失敗する事故を防ぐ）。アプリ内通知(InquiryNotifier)とは別経路で追加する。
    InquiryMessageMailJob.perform_later(first_message.id)

    redirect_to admin_inquiry_path(@inquiry), notice: "問い合わせを作成しました。"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def set_inquiry
    @inquiry = Inquiry.find(params[:id])
  end

  def inquiry_params
    params.require(:inquiry).permit(
      :order_id, :title, :category, :status, :is_visible_to_agent,
      :after_urgency, :after_type, :after_area, :reception_channel,
      :first_responder_name, :next_responder_name
    )
  end
end
