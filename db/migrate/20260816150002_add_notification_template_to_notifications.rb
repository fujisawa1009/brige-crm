# どの通知テンプレートから作成された通知かを追跡する外部キー（04 R4タスク2・テンプレート未結線の補完）。
# optional（null許可）: テンプレートを使わず手入力で作った通知も許すため。件名・本文は作成時に
# テンプレートから「コピー」して notifications 側の subject/body へ保存する設計（ライブ参照ではない）
# なので、この列はあくまで由来の記録用。テンプレートを後から編集しても送信済み通知の本文は変わらない。
class AddNotificationTemplateToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :notification_template_id, :uuid
    add_index :notifications, :notification_template_id
    # テンプレート削除で通知を消したくない＝nullify（由来が失われても通知本体は残す）。
    add_foreign_key :notifications, :notification_templates, column: :notification_template_id, on_delete: :nullify
  end
end
