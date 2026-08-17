# 問い合わせ・返信のメール通知（04 R4タスク1・メール送信欠落の補完。Laravel InquiryMessageMail 移植）。
# InquiryMessageMailJob が RecipientResolver#expand_for_send で解決した宛先ごとに呼ぶ。
# 代表アドレスを to、残りを cc に載せる（グループ以外の agency は複数メールを持ちうるため cc 展開する）。
class InquiryMailer < ApplicationMailer
  def message_notification(inquiry, message, to_email, cc_emails: [])
    @inquiry = inquiry
    @message = message

    # 添付は InquiryMessage の Active Storage をそのまま同報する（Laravel InquiryMessageMail#attachments 踏襲）。
    if message.attachments.attached?
      message.attachments.each do |attachment|
        attachments[attachment.filename.to_s] = attachment.download
      end
    end

    # 件名は Laravel envelope（【問い合わせ】タイトル（番号））に合わせる。title は任意入力のため空を吸収。
    subject = format("【問い合わせ】%s（%s）", inquiry.title.presence || "(無題)", inquiry.inquiry_number)
    mail(to: to_email, cc: cc_emails.presence, subject: subject)
  end
end
