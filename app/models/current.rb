# リクエスト単位のコンテキスト（04 R0-8）。ftlogのCurrentから acts_as_tenant 同期（organization=）を
# 除去した単一テナント版。TracksUser concern（app/models/concerns/tracks_user.rb）がCurrent.userを
# 参照してcreated_by/updated_byを自動セットする。
class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :ip_address
  attribute :request_id
end
