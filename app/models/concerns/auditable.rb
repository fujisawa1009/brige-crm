# モデルのフィールド変更監査（04 R0-7。ftlogのAuditable concernを単一テナント化して移植）。
# ftlog原本はacts_as_tenant前提でAuditLogをテナント文脈内に作っていたが、brige-crmは
# 単一テナントのためその配線（ActsAsTenant.with_tenant）を除去している。
module Auditable
  extend ActiveSupport::Concern

  # 監査対象クラス => 記録するフィールド一覧。秘匿値（encrypted_password等）は絶対に含めない。
  TRACKED_FIELDS = {
    "User"       => %w[name email is_active agency_group_id agency_id],
    "SystemRole" => %w[name display_name description super_admin],
    "IpAllowlistEntry" => %w[cidr note],
    # 04 R1: 組織・アカウント系（AgencyGroup/Agency/SalesRepresentative/ContractCondition）を追加。
    "AgencyGroup" => %w[name service_type group_code contact_email bridge_plan_display_type csv_download_visible],
    "Agency"      => %w[name agency_code agency_group_id contact_person electronic_contract_enabled csv_download_visible],
    "SalesRepresentative" => %w[name sales_rep_code agency_id email is_active],
    "ContractCondition"   => %w[name agency_id effective_from effective_until],
    # 04 R2: CRM中核。billing_password（Order）・system_account_id等（OrderWorkDetail）はPII暗号化対象の
    # ため絶対に含めない（Auditable冒頭コメントの原則どおり。差分は業務上重要な列のみ追跡する）。
    "Customer" => %w[name status agency_id sales_representative_id applied_at contracted_at],
    "Store"    => %w[store_name customer_id is_active],
    "Order"    => %w[status contract_status agency_id customer_id store_id plan_id contract_condition_id
                      ordered_at contract_start_date cancelled_at terminated_at],
    "Product"             => %w[name code is_active],
    "Plan"                => %w[name code product_id monthly_fee is_active],
    "ProductInitialFee"   => %w[name amount product_id is_active],
    "ProductOption"       => %w[name monthly_fee product_id is_active],
    "OptionGroup"         => %w[key label is_active],
    "OptionValue"         => %w[value label option_group_id parent_id is_active],
    "CustomerStatus"      => %w[code label is_active is_system],
    "OrderStatus"         => %w[code label is_active is_system],
    "ProductionCompany"   => %w[name email phone is_active],
    "SalesMaterial"       => %w[title category is_published],
    # 04 R3: フォームビルダー（管理画面）で編集される定義データ。form_fieldsのinput_options等は
    # 動的な選択肢データでノイズが大きいため追跡対象から外し、構造を特定する列のみ追う。
    "FormTemplate" => %w[product_id name is_active],
    "FormStep"     => %w[form_template_id step_number name],
    "FormField"    => %w[form_step_id field_key label field_type target_table target_column required
                          editable_by_tier lock_after_status],
    # 04 R4: 問い合わせ・通知系。InquiryMessage.body / Notification.body はメール本文の全文で
    # ノイズが大きく個人情報を含みうるため追跡対象から外し、構造・状態を特定する列のみ追う
    # （TRACKED_FIELDSの原則: 秘匿値/本文のような大きい自由記述は入れない）。
    "Inquiry"                => %w[category status order_id is_visible_to_agent],
    "InquiryMessage"         => %w[inquiry_id],
    "InquiryStatus"          => %w[category code label is_active is_system],
    "InquiryRecipientRoute"  => %w[category status_code recipient_group_id],
    "RecipientGroup"         => %w[name is_active],
    "NotificationTemplate"   => %w[name template_type subject],
    "Notification"           => %w[title target_type status scheduled_at],
    # R6-1: 個人ごとの通知設定。PIIを含まないためON/OFF状態をそのまま追跡する。
    "StaffNotificationSetting"    => %w[user_id event_type app_enabled email_enabled],
    "CustomerNotificationSetting" => %w[customer_id event_type app_enabled email_enabled],
    # R6-3: システム設定（シングルトン。admin専有で書き換え頻度は低いが、値の変更が問い合わせ添付の
    # アップロード可否に直結するため変更履歴を残す）。
    "SystemSetting" => %w[inquiry_attachment_max_count inquiry_attachment_max_size_mb]
  }.freeze

  included do
    after_create  { audit_record(:created) }
    after_update  { audit_on_update }
    after_destroy { audit_record(:destroyed) }
  end

  private

  def audit_on_update
    if respond_to?(:deleted_at) &&
       saved_change_to_deleted_at.present? &&
       saved_change_to_deleted_at.first.nil? &&
       deleted_at.present?
      audit_record(:destroyed)
    else
      audit_record(:updated)
    end
  end

  # 監査ログ上の資源種別。STIなどでクラス名と監査上の種別を一致させたくない場合にモデル側で上書きする。
  def audit_resource_type = self.class.name

  def audit_record(action)
    return unless Current.user

    fields = TRACKED_FIELDS[audit_resource_type] || []
    before = nil
    after  = nil

    case action
    when :created
      after = filtered_current(fields)
    when :updated
      changed = fields.select { |f| has_attribute?(f) && saved_change_to_attribute?(f) }
      return if changed.empty?
      before = changed.each_with_object({}) { |f, h| h[f] = attribute_before_last_save(f) }
      after  = changed.each_with_object({}) { |f, h| h[f] = public_send(f) }
    when :destroyed
      before = filtered_current(fields)
    end

    AuditLog.create!(
      user_id:        Current.user.id,
      user_type:      Current.user.class.name,
      action:         action,
      resource_type:  audit_resource_type,
      resource_id:    id,
      resource_label: try(:display_name) || try(:name) || try(:cidr),
      changes_before: before,
      changes_after:  after,
      ip_address:     Current.ip_address,
      source:         "web",
      request_id:     Current.request_id
    )
  end

  def filtered_current(fields)
    return {} if fields.empty?
    fields.each_with_object({}) { |f, h| h[f] = public_send(f) if has_attribute?(f) }
  end
end
