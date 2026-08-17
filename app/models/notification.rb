# 一斉通知（04 R4タスク3。Laravel Notification.php移植。db/migrate/20260815160009参照）。
# フィルタ(filter_params)・スケジュール送信・宛先グループの3点を持つ。実送信は
# NotificationDeliveryJob（app/jobs/notification_delivery_job.rb）が担い、このモデル自身は
# 「誰に送るか」の解決（resolve_recipients）と状態遷移のみを持つ（Fat Model/Thin Jobではなく
# 宛先解決ロジックをジョブに埋めるとテストしづらくなるための分離）。
# == Schema Information
#
# Table name: notifications
#
#  id             :uuid             not null, primary key
#  body           :text
#  failed_count   :integer          default(0), not null
#  filter_params  :jsonb            not null
#  scheduled_at   :datetime
#  sent_at        :datetime
#  status         :string           default("draft"), not null
#  subject        :string
#  success_count  :integer          default(0), not null
#  target_type    :string           not null
#  title          :string           not null
#  total_count    :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  created_by_id  :uuid
#  updated_by_id  :uuid
#
# Indexes
#
#  index_notifications_on_status        (status)
#  index_notifications_on_scheduled_at  (scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class Notification < ApplicationRecord
  include TracksUser
  include Auditable

  STATUS_DRAFT     = "draft"
  STATUS_SCHEDULED = "scheduled"
  STATUS_SENDING   = "sending"
  STATUS_SENT      = "sent"
  STATUS_FAILED    = "failed"

  STATUSES = [ STATUS_DRAFT, STATUS_SCHEDULED, STATUS_SENDING, STATUS_SENT, STATUS_FAILED ].freeze

  TARGET_AGENCY   = "agency"
  TARGET_CUSTOMER = "customer"

  TARGET_TYPES = [ TARGET_AGENCY, TARGET_CUSTOMER ].freeze

  has_many :notification_recipients, dependent: :destroy
  has_many_attached :attachments

  validates :title, presence: true, length: { maximum: 255 }
  validates :target_type, presence: true, inclusion: { in: TARGET_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :scheduled_at_required_when_scheduled

  # スケジュール送信登録（04 R4本文「スケジュール送信はSolid Queueのdelayed jobで実装」）。
  # cronでの毎分ポーリングではなく、Solid Queueのwait_untilで発火時刻をジョブ側に持たせる
  # （Laravel現行のconsole.php「予約通知配信(毎分)」をポーリング無しで代替できる）。
  def schedule!(scheduled_at)
    update!(status: STATUS_SCHEDULED, scheduled_at: scheduled_at)
    NotificationDeliveryJob.set(wait_until: scheduled_at).perform_later(id)
  end

  # 即時配信登録（scheduled_atなし＝今すぐSolid Queueへ投入）。
  def deliver_now_via_job!
    update!(status: STATUS_SCHEDULED, scheduled_at: Time.current)
    NotificationDeliveryJob.perform_later(id)
  end

  # target_type/filter_paramsから宛先を解決する（NotificationDeliveryJobから呼ばれる）。
  # メールが無い宛先は送信不能なので除外する（success/failed集計を「送れたはずの宛先」に限定する）。
  def resolve_recipients
    case target_type
    when TARGET_AGENCY   then agency_recipients
    when TARGET_CUSTOMER then customer_recipients
    else []
    end
  end

  private

  def agency_recipients
    scope = Agency.all
    scope = scope.where(agency_group_id: filter_params["agency_group_id"]) if filter_params["agency_group_id"].present?

    scope.filter_map do |agency|
      email = [ agency.email_1, agency.email_2, agency.email_3, agency.email_4, agency.email_5 ].compact_blank.first
      next if email.blank?

      { recipient_type: "Agency", recipient_id: agency.id, email: email }
    end
  end

  def customer_recipients
    scope = Customer.active
    scope = scope.where(status: filter_params["status"]) if filter_params["status"].present?
    scope = scope.where(agency_id: filter_params["agency_id"]) if filter_params["agency_id"].present?

    scope.where.not(email: [ nil, "" ]).map do |customer|
      { recipient_type: "Customer", recipient_id: customer.id, email: customer.email }
    end
  end

  def scheduled_at_required_when_scheduled
    return unless status == STATUS_SCHEDULED

    errors.add(:scheduled_at, "はステータスがscheduledの場合必須です") if scheduled_at.blank?
  end
end
