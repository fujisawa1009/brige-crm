# frozen_string_literal: true

# 04 R2タスク2（Column.md §11 jasmin_order_work_details が正）。Orderと1:1。
#
# PII暗号化（pii-handling-rules.md §1 分類B）: SNSアカウントID/PASS（Instagram/Facebook/Google）・
# システムアカウントID/PASSの8カラムを t.text にしている（暗号化後のデータはBase64込みで平文より
# かなり長くなるため。app/models/order_work_detail.rb の encrypts宣言と対）。
class CreateOrderWorkDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :order_work_details, id: :uuid do |t|
      t.uuid :order_id, null: false

      # システムアカウント（PII-B暗号化対象）
      t.text :system_account_id
      t.text :system_account_pass
      t.text :google_account_id
      t.text :google_account_pass

      # Instagram / Facebook
      t.string :instagram_account, limit: 20
      t.text :instagram_id
      t.text :instagram_pass
      t.string :instagram_login_confirmed, limit: 20
      t.text :facebook_id
      t.text :facebook_pass
      t.string :has_facebook, limit: 10
      t.string :has_instagram, limit: 10
      t.string :has_google_business, limit: 10

      # GBP
      t.string :gbp_permission, limit: 30
      t.string :gbp_owner_permission, limit: 20
      t.string :gbp_owner_name, limit: 100
      t.string :gbp_owner_contact, limit: 100
      t.string :gbp_owner_permission_granted, limit: 20
      t.string :gbp_url, limit: 500
      t.string :gbp_site_url, limit: 500
      t.string :gbp_delete_new, limit: 10
      t.string :reference_url, limit: 500

      # キーワード設定
      t.string :keyword_region_industry, limit: 200
      t.string :keyword_prefecture, limit: 20
      t.string :keyword_city, limit: 50
      t.string :keyword_area_1, limit: 50
      t.string :keyword_area_2, limit: 50
      t.string :keyword_area_3, limit: 50
      t.string :keyword_industry_main, limit: 50
      t.string :keyword_industry_sub1, limit: 50
      t.string :keyword_industry_sub2, limit: 50
      t.string :keyword_industry_sub3, limit: 50
      t.string :keyword_industry_sub4, limit: 50
      t.text :keyword_remarks
      t.string :business_category_keyword, limit: 200
      t.string :industry_keyword, limit: 200

      # 店舗詳細（GBP登録用）
      t.string :business_type, limit: 30
      t.date :opening_date
      t.integer :num_employees
      t.string :capital, limit: 50
      t.string :nearest_station, limit: 100
      t.string :directions, limit: 500
      t.string :parking, limit: 20
      t.integer :parking_capacity
      t.string :barrier_free, limit: 10
      t.string :wifi_available, limit: 30
      t.string :accepted_cards, limit: 200
      t.string :logo_photo, limit: 100
      t.integer :num_stores
      t.string :business_account_name, limit: 100
      t.string :lunch_hours, limit: 30
      t.string :dinner_hours, limit: 30
      t.string :available_from, limit: 30
      t.string :order_time, limit: 30
      t.string :attribute_1, limit: 100
      t.string :attribute_2, limit: 100
      t.string :attribute_3, limit: 100
      t.string :attribute_4, limit: 100
      t.string :attribute_5, limit: 100
      t.string :attribute_6, limit: 100
      t.string :attribute_7, limit: 100
      t.string :attribute_8, limit: 100
      t.string :attribute_9, limit: 100
      t.string :attribute_10, limit: 100
      t.string :attribute_11, limit: 100

      # 連絡・ヒアリング
      t.string :hearing_system, limit: 50
      t.string :contact_easy_time, limit: 100
      t.string :contact_easy_time_note, limit: 200
      t.string :contact_easy_day, limit: 100
      t.string :contact_easy_day_note, limit: 200

      # 作業記録（運用）
      t.text :operation_history
      t.text :work_progress_notes

      t.timestamps
      t.uuid :created_by_id
      t.uuid :updated_by_id
    end

    add_index :order_work_details, :order_id, unique: true

    add_foreign_key :order_work_details, :orders, on_delete: :cascade
    add_foreign_key :order_work_details, :users, column: :created_by_id
    add_foreign_key :order_work_details, :users, column: :updated_by_id
  end
end
