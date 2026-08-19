# 管理画面ユーザー（社内/代理店グループ/代理店）。03§4決定D: JasminCustomer相当のマイページは
# 別モデルCustomer（R4）、受注入力はSalesRepresentative（R3・Devise対象外）として分離するため、
# UserはこのR0時点では管理画面(admin section)専用でよい（ftlogのようなSTIは不要）。
#
# 04 R1: agency_group_id / agency_id で「所属」を表現する（Laravel User.php踏襲）。
#   admin / 実務運用者:   両方 NULL（Pundit AgencyScoped の staff_scope。全件アクセス可）
#   代理店グループ担当者: agency_group_id のみ設定
#   代理店担当者:         agency_id のみ設定
# 両方同時に設定することは許可しない（#agency_scope_is_exclusive）。この不変条件が崩れると
# app/policies/concerns/agency_scoped.rb のスコープ判定が意図通りに動かなくなるため必須。
# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  is_active              :boolean          default(TRUE), not null
#  locked_at              :datetime
#  name                   :string           default(""), not null
#  otp_attempts           :integer          default(0), not null
#  otp_code_digest        :string
#  otp_code_expires_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  agency_group_id        :uuid
#  agency_id              :uuid
#
# Indexes
#
#  index_users_on_agency_group_id       (agency_group_id)
#  index_users_on_agency_id             (agency_id)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_group_id => agency_groups.id) ON DELETE => restrict
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :lockable, :timeoutable

  # OtpAuthenticatable より後、AuthAuditable より前に include すること：
  # AuthAuditable#after_otp_event は otp_authenticatable の after_otp_event(super) を呼び出す前提。
  include OtpAuthenticatable
  include AuthAuditable
  include Auditable

  has_many :user_system_roles, dependent: :destroy
  has_many :system_roles, through: :user_system_roles
  # R6-1: 個人ごとの通知設定（マイページ相当画面から本人のみ編集）。
  has_many :staff_notification_settings, dependent: :destroy

  belongs_to :agency_group, optional: true
  belongs_to :agency, optional: true

  validates :name,  presence: true, length: { maximum: 50 }
  validates :email, length: { maximum: 255 }
  validate  :agency_scope_is_exclusive

  def super_admin?
    system_roles.exists?(super_admin: true)
  end

  # is_active=false のユーザーはログイン不可にする（04 R1で追加した無効化フラグ。
  # フラグを持たせるだけで認証経路を止めなければ実効性がないため、Devise標準の
  # active_for_authentication?を上書きする。メッセージはDeviseの既定の:inactiveキーを使う）。
  def active_for_authentication?
    super && is_active?
  end

  # Devise が送る通知メール（パスワード変更通知・再設定メール等）を非同期（Solid Queue）で送る。
  # 同期送信だとSMTP障害がユーザー操作自体を500にしてしまうため（ftlog踏襲）。
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  private

  def agency_scope_is_exclusive
    return unless agency_id.present? && agency_group_id.present?

    errors.add(:agency_group_id, "は agency_id と同時に設定できません（代理店担当者は agency_id のみ、" \
      "代理店グループ担当者は agency_group_id のみを設定すること。Laravel現行 Column.md §1/§2 の運用規約踏襲）")
  end
end
