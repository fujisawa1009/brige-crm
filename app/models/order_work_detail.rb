# 案件作業詳細（GBP/SNS。04 R2タスク2。Column.md §11 jasmin_order_work_details が正）。Orderと1:1。
#
# PII（pii-handling-rules.md §1 分類B: SNSアカウントID/PASS・システムアカウントID/PASS）。
#
# 【2026-08-19 CEO決定（Q-45）: 暗号化を廃止し平文保存に変更】
# 従来は対象8カラムへ ActiveRecord::Encryption の encrypts を適用していたが、申込フォーム
# （FormField の動的マッピング）で Instagram ID/パスワードを必須入力にしたいという業務要件
# （2026-08-18 浅賀MTG）に対し、暗号化列は FormField.allowed_target_columns_for から機構的に
# 除外される設計だったため衝突した。決定にあたり秘書から「①encrypts は非決定的暗号のため
# スタッフは管理画面で従来どおり値を読めており業務影響は無い ②必須化できない原因は暗号化では
# なくホワイトリスト設定で、専用ステップ実装なら暗号化のまま必須化できる ③対象は顧客が他社
# サービスで使用中の実パスワードで分類B（最厳格）」を説明したうえで、CEOが平文保存を再確認・確定した。
#
# 平文化に伴い、これらのカラムの保護はアクセス制御（RBAC＋Pundit スコープ＋IP許可リスト＋メールOTP）・
# 監査ログ（Auditable の TRACKED_FIELDS から除外することで値自体は AuditLog に残さない）・
# ログのパラメータフィルタ（config/initializers/filter_parameter_logging.rb）・
# DB/バックアップの at-rest 暗号化（R8 で要件化）に依存する。
# == Schema Information
#
# Table name: order_work_details
#
#  id                           :uuid             not null, primary key
#  accepted_cards               :string(200)
#  attribute_1                  :string(100)
#  attribute_10                 :string(100)
#  attribute_11                 :string(100)
#  attribute_2                  :string(100)
#  attribute_3                  :string(100)
#  attribute_4                  :string(100)
#  attribute_5                  :string(100)
#  attribute_6                  :string(100)
#  attribute_7                  :string(100)
#  attribute_8                  :string(100)
#  attribute_9                  :string(100)
#  available_from               :string(30)
#  barrier_free                 :string(10)
#  business_account_name        :string(100)
#  business_category_keyword    :string(200)
#  business_type                :string(30)
#  capital                      :string(50)
#  contact_easy_day             :string(100)
#  contact_easy_day_note        :string(200)
#  contact_easy_time            :string(100)
#  contact_easy_time_note       :string(200)
#  dinner_hours                 :string(30)
#  directions                   :string(500)
#  facebook_pass                :text
#  gbp_delete_new               :string(10)
#  gbp_owner_contact            :string(100)
#  gbp_owner_name               :string(100)
#  gbp_owner_permission         :string(20)
#  gbp_owner_permission_granted :string(20)
#  gbp_permission               :string(30)
#  gbp_site_url                 :string(500)
#  gbp_url                      :string(500)
#  google_account_pass          :text
#  has_facebook                 :string(10)
#  has_google_business          :string(10)
#  has_instagram                :string(10)
#  hearing_system               :string(50)
#  industry_keyword             :string(200)
#  instagram_account            :string(20)
#  instagram_login_confirmed    :string(20)
#  instagram_pass               :text
#  keyword_area_1               :string(50)
#  keyword_area_2               :string(50)
#  keyword_area_3               :string(50)
#  keyword_city                 :string(50)
#  keyword_industry_main        :string(50)
#  keyword_industry_sub1        :string(50)
#  keyword_industry_sub2        :string(50)
#  keyword_industry_sub3        :string(50)
#  keyword_industry_sub4        :string(50)
#  keyword_prefecture           :string(20)
#  keyword_region_industry      :string(200)
#  keyword_remarks              :text
#  logo_photo                   :string(100)
#  lunch_hours                  :string(30)
#  nearest_station              :string(100)
#  num_employees                :integer
#  num_stores                   :integer
#  opening_date                 :date
#  operation_history            :text
#  order_time                   :string(30)
#  parking                      :string(20)
#  parking_capacity             :integer
#  reference_url                :string(500)
#  system_account_pass          :text
#  wifi_available               :string(30)
#  work_progress_notes          :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  created_by_id                :uuid
#  facebook_id                  :text
#  google_account_id            :text
#  instagram_id                 :text
#  order_id                     :uuid             not null
#  system_account_id            :text
#  updated_by_id                :uuid
#
# Indexes
#
#  index_order_work_details_on_order_id  (order_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class OrderWorkDetail < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :order

  validates :instagram_account, length: { maximum: 20 }
  validates :instagram_login_confirmed, length: { maximum: 20 }
  validates :has_facebook, :has_instagram, :has_google_business, length: { maximum: 10 }
  validates :gbp_permission, length: { maximum: 30 }
  validates :gbp_owner_permission, :gbp_owner_permission_granted, length: { maximum: 20 }
  validates :gbp_owner_name, :gbp_owner_contact, length: { maximum: 100 }
  validates :gbp_url, :gbp_site_url, :reference_url, length: { maximum: 500 }
  validates :gbp_delete_new, length: { maximum: 10 }
  validates :keyword_region_industry, :business_category_keyword, :industry_keyword, length: { maximum: 200 }
  validates :keyword_prefecture, length: { maximum: 20 }
  validates :num_employees, :parking_capacity, :num_stores,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
