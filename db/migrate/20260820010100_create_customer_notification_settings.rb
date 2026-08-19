# 個人ごとの通知設定・顧客側（R6-1。2026-08-20 CEO決定＝ftlogが最終的に放棄した「顧客個人単位」の
# 設定粒度をあえて採用する。ftlogはCustomerNotificationSettingsController（顧客ごと）を後にプロジェクト
# 単位（ProjectCustomerNotificationSetting）へ置き換えたが、brige-crmは顧客がマイページから自分自身の
# 設定を編集する運用のため、社内スタッフ側と対称の customer_id × event_type 構造を新規設計する。
class CreateCustomerNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_notification_settings, id: :uuid do |t|
      t.uuid :customer_id, null: false
      t.string :event_type, null: false
      t.boolean :app_enabled, null: false, default: true
      t.boolean :email_enabled, null: false, default: true

      t.timestamps
    end

    add_index :customer_notification_settings, %i[customer_id event_type], unique: true,
              name: "index_customer_notification_settings_on_customer_and_event"

    add_foreign_key :customer_notification_settings, :customers, on_delete: :cascade
  end
end
