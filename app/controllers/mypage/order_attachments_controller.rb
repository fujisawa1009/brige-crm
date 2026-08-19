# R6-8 ファイル管理基盤・顧客マイページ側のダウンロード経路。
#
# 現時点でマイページにOrder詳細相当の画面は存在しない（Mypage::DashboardControllerはOrder一覧の
# みで、show相当のルートが無い。app/controllers/mypage/配下を確認済み）。R6-8要件「もしマイページ等に
# 既にOrder詳細相当の画面があれば、そこでis_visible_to_customer=trueのファイルのみ見えるように
# する。無ければ管理画面側の実装のみで良い」を踏まえ、Order詳細画面そのものは追加しないが、
# ダウンロード経路（将来のR5-11契約書PDF等で実際に使われる想定の入口）だけを最小実装しておく。
#
# 認可はPunditを使わない（Mypage::BaseControllerの他コントローラーと同じ方針。OrderAttachmentPolicyの
# AgencyScoped#staff_scope?等はUser想定でCustomerには適用できないため、ここではクエリスコープ自体で
# 「自分のOrderの、is_visible_to_customer=trueのファイルのみ」に絞り込み、都度アクセス時に再評価する
# ことで認可チェックとする（ftlogの「署名付きURL発行後は都度権限再チェックしない」設計を踏襲しない、
# というR6-8要件をmypage側でも満たす。rails_blob_pathへの直接リンクは使わずsend_dataで都度取得する）。
class Mypage::OrderAttachmentsController < Mypage::BaseController
  def download
    order_attachment = OrderAttachment
                          .joins(:order)
                          .where(orders: { customer_id: current_customer.id })
                          .visible_to_customer
                          .find(params[:id])

    file = order_attachment.file
    send_data file.download, filename: file.filename.to_s, type: file.content_type,
              disposition: "attachment"
  end
end
