# 営業担当者（04 R1・Column.md §7）。受注入力画面（R3）の認証キー=代理店CD＋営業担当者CD。
# T-2是正済み: sales_rep_code はLaravel現行が既にグローバルユニークなのでそのまま踏襲する
# （代理店内ユニークではなくシステム全体でユニーク）。
#
# 04 R3・03§8-2 Q-23: 受注入力ログインは「代理店CD＋営業担当者CDでの本人特定」→「メールOTP」の
# 2段階（Form::SessionsController→Form::OtpsController）。OtpAuthenticatable concernをR0のUser同様に
# includeして再利用する（app/models/concerns/otp_authenticatable.rb冒頭コメントどおりの横展開）。
# AuthAuditableはDevise（valid_password?/lock_access!等）前提のためincludeせず、after_otp_eventだけを
# 直接オーバーライドしてAuditLogへ橋渡しする（Deviseに依存しない最小実装）。
# == Schema Information
#
# Table name: sales_representatives
#
#  id                  :uuid             not null, primary key
#  email               :string
#  is_active           :boolean          default(TRUE), not null
#  name                :string           not null
#  otp_attempts        :integer          default(0), not null
#  otp_code_digest     :string
#  otp_code_expires_at :datetime
#  pdf_address_detail  :string
#  pdf_city            :string
#  pdf_fax_number      :string
#  pdf_phone_number    :string
#  pdf_postal_code     :string
#  pdf_prefecture      :string
#  pdf_store_name      :string
#  pdf_town            :string
#  sales_rep_code      :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  agency_id           :uuid             not null
#  created_by_id       :uuid
#  updated_by_id       :uuid
#
# Indexes
#
#  index_sales_representatives_on_agency_id       (agency_id)
#  index_sales_representatives_on_email           (email)
#  index_sales_representatives_on_is_active       (is_active)
#  index_sales_representatives_on_sales_rep_code  (sales_rep_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class SalesRepresentative < ApplicationRecord
  include TracksUser
  include Auditable
  include OtpAuthenticatable

  belongs_to :agency

  # 04 R2: 担当顧客・案件（Column.md §8/§10）。destroy時はnullify（顧客・案件データ自体は残す）。
  has_many :customers, dependent: :nullify
  has_many :orders, dependent: :nullify
  # 04 R3: 受注入力（申込トランザクション）の進行中・完了レコード。
  has_many :applications, dependent: :restrict_with_error

  validates :sales_rep_code, presence: true, uniqueness: true, length: { maximum: 50 } # T-2: グローバルユニーク
  validates :name, presence: true, length: { maximum: 100 }
  validates :email, length: { maximum: 255 }

  scope :active, -> { where(is_active: true) }

  private

  # OtpAuthenticatable#generate_otp_code!/verify_otp_code のイベント発生時に呼ばれる（04 R0-4）。
  # AuditLog.user_idはUser以外も許容する設計（db/migrate/20260815120006_create_audit_logs.rbのFK
  # 非設定コメント参照）のため、自身のidをそのまま記録できる。
  def after_otp_event(event)
    super
    AuditLog.create!(
      user_id:        id,
      user_type:      self.class.name,
      action:         event.to_s,
      resource_type:  "SalesRepresentative",
      resource_id:    id,
      resource_label: sales_rep_code,
      ip_address:     Current.ip_address,
      source:         "web",
      request_id:     Current.request_id
    )
  end
end
