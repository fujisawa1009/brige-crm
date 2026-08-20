# 問い合わせメッセージの返信（04 R4タスク1。inquiries配下のネストリソース）。
# ステータス変更を伴う返信＝board-implementation-options.md §2-2「ステータス選択＝宛先自動決定」を
# ここで実現する: paramsにstatusが含まれていればInquiry#statusを更新してから宛先解決するため、
# 新しいステータスに対応したルーティング（InquiryRecipientRoute）が反映される。
class Admin::InquiryMessagesController < Admin::BaseController
  before_action :set_inquiry

  def create
    authorize @inquiry, :show?

    # E10（2026-08-20 CEO決定）: 返信時に次回対応者（部門＝RecipientGroup）も切り替えられるようにする。
    # 業務上「次回対応者」は返信のたびに引き継がれるため、statusと同じく返信フォームから受ける。
    # 空文字は「なし（未指定）」＝NULLとして扱い、宛先解決はステータス×ルートへフォールバックする。
    inquiry_attrs = {}
    inquiry_attrs[:status] = params[:status] if params[:status].present?
    inquiry_attrs[:next_responder_group_id] = params[:next_responder_group_id].presence if params.key?(:next_responder_group_id)
    @inquiry.update!(inquiry_attrs) if inquiry_attrs.any?

    message = @inquiry.inquiry_messages.new(inquiry_message_params)

    ActiveRecord::Base.transaction do
      message.save!
      message.assign_recipients!(RecipientResolver.recipients_for_inquiry(@inquiry))
      InquiryNotifier.notify_message_created(message)
    end

    # メール通知はコミット確定後にenqueue（未コミット中にジョブが走る事故を防ぐ）。
    # アプリ内通知(InquiryNotifier)は維持し、メール送信を追加する形。
    InquiryMessageMailJob.perform_later(message.id)

    redirect_to admin_inquiry_path(@inquiry), notice: "メッセージを送信しました。"
  rescue ActiveRecord::RecordInvalid
    redirect_to admin_inquiry_path(@inquiry), alert: message.errors.full_messages.to_sentence
  end

  private

  def set_inquiry
    @inquiry = Inquiry.find(params[:inquiry_id])
  end

  def inquiry_message_params
    # inquiry_template_id はR6-4のテンプレート由来メタ情報。存在しないIDが送られた場合は
    # InquiryMessage#inquiry_templateのpresenceバリデーションで弾く（モデル側で担保）。
    params.require(:inquiry_message).permit(:body, :inquiry_template_id, attachments: [])
  end
end
