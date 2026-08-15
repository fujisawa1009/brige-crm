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
    "ContractCondition"   => %w[name agency_id effective_from effective_until]
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
