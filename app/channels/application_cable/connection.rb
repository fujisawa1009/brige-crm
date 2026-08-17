module ApplicationCable
  # アプリ内通知（04 R4タスク4）のためのCable接続。管理画面ユーザー(User)・顧客マイページ(Customer)の
  # どちらのDeviseセッションでも接続できるようにする（受注入力=SalesRepresentativeはR4スコープ外。
  # 04 R4本文にform sectionのアプリ内通知は含まれていない）。
  #
  # DeviseはWardenのセッションをCookie経由でActionCableのHTTPアップグレードリクエストにも渡すため、
  # env["warden"] から両スコープを順に確認できる（ftlogにActionCable実装が無いためRails標準の
  # 手順で新規実装。Rails公式ガイドの「Devise + ActionCableの認証」パターンを踏襲）。
  class Connection < ActionCable::Connection::Base
    identified_by :current_recipient_type, :current_recipient_id

    def connect
      recipient = find_verified_recipient
      reject_unauthorized_connection unless recipient

      self.current_recipient_type = recipient.class.name
      self.current_recipient_id   = recipient.id
    end

    private

    def find_verified_recipient
      warden = request.env["warden"]
      warden&.user(:user) || warden&.user(:customer)
    end
  end
end
