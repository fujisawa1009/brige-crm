# 個人ごとの通知設定の判定ロジック集約（R6-1。ftlogの設計思想＝「自分の操作を除外する」「通知設定を
# 見る」といった判定は配信直前の1箇所にまとめる、を踏襲）。
#
# 既存の配信箇所（StaffNotificationMailer/Form::ApplicationMailer/InquiryNotifier/
# InquiryMessageMailJob/NotificationDeliveryJob）はいずれも RecipientResolver 等が解決した
# [{type:, id:}, ...] 形式の宛先を扱っている（RecipientResolverのコメント参照）。このクラスも同じ
# type/id の形（recipient_type: Railsクラス名文字列 / recipient_id: uuid）を受け取ることで、
# 各呼び出し箇所は「宛先オブジェクトを読み込み直す」追加コストなしにそのままゲートへ渡せる。
#
# 個人設定を持つのは User（社内スタッフ）と Customer（顧客）の2種のみ（R6-1のスコープ）。
# Agency/SalesRepresentative/ProductionCompany/RecipientGroup 等、個人設定の概念が無い宛先種別は
# 常に許可する（フェイルオープン＝この機能が無かった時と同じ「常時通知」の挙動を維持する）。
class NotificationSettingGate
  # recipient_type（Railsクラス名文字列）→ [設定モデル, 所有者列] の対応表。
  SETTING_MODELS = {
    "User"     => [ -> { StaffNotificationSetting },    :user_id ],
    "Customer" => [ -> { CustomerNotificationSetting },  :customer_id ]
  }.freeze

  def self.app_enabled?(recipient_type:, recipient_id:, event_type:)
    new(recipient_type: recipient_type, recipient_id: recipient_id, event_type: event_type).app_enabled?
  end

  def self.email_enabled?(recipient_type:, recipient_id:, event_type:)
    new(recipient_type: recipient_type, recipient_id: recipient_id, event_type: event_type).email_enabled?
  end

  def initialize(recipient_type:, recipient_id:, event_type:)
    @recipient_type = recipient_type
    @recipient_id   = recipient_id
    @event_type     = event_type
  end

  def app_enabled?
    return true unless setting_model

    setting ? setting.app_enabled? : setting_model::DEFAULT_APP_ENABLED
  end

  def email_enabled?
    return true unless setting_model

    setting ? setting.email_enabled? : setting_model::DEFAULT_EMAIL_ENABLED
  end

  private

  attr_reader :recipient_type, :recipient_id, :event_type

  def setting_model
    config = SETTING_MODELS[recipient_type]
    config && config[0].call
  end

  def owner_column
    SETTING_MODELS.fetch(recipient_type)[1]
  end

  def setting
    return @setting if defined?(@setting)

    @setting = setting_model.find_by(owner_column => recipient_id, event_type: event_type)
  end
end
