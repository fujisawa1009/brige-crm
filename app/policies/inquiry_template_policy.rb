# frozen_string_literal: true

# R6-4: 問い合わせ返信テンプレート管理。NotificationTemplatePolicy等と同じ内部運用マスタ扱い
# （index/showは全ロール、書き込みはstaff_scope?限定）。role_seeder.rbで実務運用者専有
# （代理店/代理店グループへは参照権限すら渡さない。notification_templates等と同じ扱い）。
class InquiryTemplatePolicy < ApplicationPolicy
  include MasterDataPolicy
end
