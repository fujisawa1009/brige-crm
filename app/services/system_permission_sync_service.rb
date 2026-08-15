require "set"

# ルート→権限カタログの自動同期（04 R0-5）。ftlogのSystemPermissionSyncServiceを移植し、
# section判定を admin/form/mypage の3区分（決定C）に拡張した。
#
# review-02 ➕1/➕2の指摘を反映: EXCLUDED_ACTIONS（controller+action粒度の除外）を
# EXCLUDED_CONTROLLER_PREFIXESとは別枠で持つ（R0時点では該当アクションが無いため空だが、
# 将来の内部API的アクション追加に備えて仕組みごと移植しておく）。
class SystemPermissionSyncService
  Result = Struct.new(:created, :updated, :disabled, :active, keyword_init: true)

  # ftlog原本の active_storage/ rails/ devise/ platform_admin/ turbo/ manual/ portal/manual/ portal/faq
  # のうち、brige-crmに存在しない機能（platform_admin/マニュアル/FAQ）は除外済み。
  EXCLUDED_CONTROLLER_PREFIXES = %w[
    active_storage/
    rails/
    devise/
    turbo/
  ].freeze

  # controller+action粒度の除外（review-02 ➕1）。R0時点では該当なし。
  EXCLUDED_ACTIONS = {}.freeze

  def self.call
    new.call
  end

  def call
    created = 0
    updated = 0
    disabled = 0
    active_signatures = Set.new

    SystemPermission.transaction do
      route_permissions.each do |attributes|
        active_signatures.add(route_signature(attributes))

        permission = SystemPermission.find_or_initialize_by(
          controller: attributes[:controller],
          action:     attributes[:action],
          http_method: attributes[:http_method],
          path:        attributes[:path]
        )

        created += 1 if permission.new_record?
        permission.name    = attributes[:name]
        permission.section = attributes[:section]
        permission.enabled = true

        if permission.changed?
          updated += 1 unless permission.new_record?
          permission.save!
        end
      end

      SystemPermission.enabled.find_each do |permission|
        next if active_signatures.include?(permission.route_signature)

        permission.update!(enabled: false)
        disabled += 1
      end

      # 除外対象コントローラー/アクションの行は無効化ではなく削除する（ftlog踏襲。
      # 権限管理画面は enabled で絞らず全行を表示するため、無効化だけでは
      # 「チェックしても意味のない行」が画面に残り続けてしまう）。
      SystemPermission.find_each do |permission|
        permission.destroy! if excluded_controller?(permission.controller) ||
                               excluded_action?(permission.controller, permission.action)
      end
    end

    Result.new(
      created: created,
      updated: updated,
      disabled: disabled,
      active: active_signatures.size
    )
  end

  private

  def route_permissions
    Rails.application.routes.routes.filter_map do |route|
      controller = route.defaults[:controller]
      action     = route.defaults[:action]
      next if controller.blank? || action.blank?
      next if excluded_controller?(controller)
      next if excluded_action?(controller, action)

      {
        controller:  controller,
        action:      action,
        http_method: http_method(route),
        path:        route.path.spec.to_s.sub("(.:format)", ""),
        name:        "#{controller}##{action}",
        section:     section_for(controller)
      }
    end.uniq { |attributes| route_signature(attributes) }
  end

  def excluded_controller?(controller)
    EXCLUDED_CONTROLLER_PREFIXES.any? { |prefix| controller.start_with?(prefix) }
  end

  def excluded_action?(controller, action)
    action.in?(EXCLUDED_ACTIONS.fetch(controller, []))
  end

  # admin / form / mypage の3区分（決定C）。SyncServiceがコントローラのネームスペースから自動判定する
  # （ftlogの「portal/」始まりで customer 判定するロジックの拡張）。
  def section_for(controller)
    return "form"   if controller.start_with?("form/")
    return "mypage" if controller.start_with?("mypage/")
    "admin"
  end

  def http_method(route)
    verb = route.verb
    verb = verb.source if verb.respond_to?(:source)
    method = verb.delete("^A-Z|")
    method.presence || "ALL"
  end

  def route_signature(attributes)
    [
      attributes[:controller],
      attributes[:action],
      attributes[:http_method],
      attributes[:path]
    ]
  end
end
