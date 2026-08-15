# 管理画面ユーザー（社内/代理店グループ/代理店）。03§4決定D: JasminCustomer相当のマイページは
# 別モデルCustomer（R4）、受注入力はSalesRepresentative（R3・Devise対象外）として分離するため、
# UserはこのR0時点では管理画面(admin section)専用でよい（ftlogのようなSTIは不要）。
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

  validates :name,  presence: true, length: { maximum: 50 }
  validates :email, length: { maximum: 255 }

  def super_admin?
    system_roles.exists?(super_admin: true)
  end

  # Devise が送る通知メール（パスワード変更通知・再設定メール等）を非同期（Solid Queue）で送る。
  # 同期送信だとSMTP障害がユーザー操作自体を500にしてしまうため（ftlog踏襲）。
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
