# 問い合わせメール送信の「実際に送った先」を記録する列（04 R4タスク1・メール送信欠落の補完。
# Laravel SendInquiryMessageJob の resolved_email 相当）。宛先が recipient_group など複数メンバーに
# 展開される場合でも、最初に送信成功したメールアドレスだけを控える（Laravel踏襲。送達確認・
# 監査の起点にする。展開後の全アドレスを持たないのは「代表1件で足りる」というLaravel運用に合わせるため）。
class AddResolvedEmailToInquiryMessageRecipients < ActiveRecord::Migration[8.1]
  def change
    add_column :inquiry_message_recipients, :resolved_email, :string
  end
end
