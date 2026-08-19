# R6-8 ファイル管理基盤（04-implementation-plan.md R6-8）。orders配下のネストリソース
# （InquiryMessagesControllerと同じ形。indexアクションは持たず、一覧は@order.order_attachmentsとして
# Admin::OrdersController#showのビューへ埋め込む＝親Orderの`authorize @order`（show?）だけで
# 到達制御される。個別のファイル操作（アップロード/削除/ダウンロード）はOrderAttachment単位で
# 都度authorizeし、代理店スコープの取り違えを防ぐ）。
#
# ダウンロードは rails_blob_path をビューへ直接埋め込まない設計にしている（ftlogの「署名付きURL
# 発行後は都度権限再チェックしない」という弱点を踏襲しないため。R6-8要件）。このコントローラーの
# #download を必ず経由させ、authorize（Pundit）を毎回実行してから send_data でファイル本体を返す。
class Admin::OrderAttachmentsController < Admin::BaseController
  before_action :set_order

  def create
    @order_attachment = @order.order_attachments.new(order_attachment_params)
    authorize @order_attachment

    if @order_attachment.save
      redirect_to admin_order_path(@order), notice: "ファイルをアップロードしました。"
    else
      redirect_to admin_order_path(@order), alert: @order_attachment.errors.full_messages.to_sentence
    end
  end

  def destroy
    order_attachment = @order.order_attachments.find(params[:id])
    authorize order_attachment

    order_attachment.destroy!
    redirect_to admin_order_path(@order), notice: "ファイルを削除しました。"
  end

  # 他代理店のOrderの添付ファイルへ到達しようとした場合は、@orderをid直指定で取得したあとの
  # authorize（show?・AgencyScoped#accessible?）で403になる（Admin::OrdersController等と同じ
  # 「unscoped findしてからauthorizeで弾く」パターン。set_orderをpolicy_scope経由にしていないのは
  # 既存コントローラー群と統一するため）。
  def download
    order_attachment = @order.order_attachments.find(params[:id])
    authorize order_attachment, :show?

    file = order_attachment.file
    send_data file.download, filename: file.filename.to_s, type: file.content_type,
              disposition: "attachment"
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  end

  def order_attachment_params
    params.require(:order_attachment).permit(:file, :file_type, :is_visible_to_customer)
  end
end
