# アプリ内通知のリアルタイム配信チャネル（04 R4タスク4・R4検証「アプリ内通知がSolid Cable経由で
# リアルタイム配信されること」）。接続済みの current_recipient（ApplicationCable::Connection）宛の
# ストリームだけを購読させる＝他人の通知を購読できないことをsubscribed側で保証する
# （SystemNotification.stream_name_forに現在の接続情報以外を渡せない実装にしている）。
class SystemNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from SystemNotification.stream_name_for(
      recipient_type: current_recipient_type,
      recipient_id:   current_recipient_id
    )
  end

  def unsubscribed
    stop_all_streams
  end
end
