# 主キーをUUIDに統一する（03-rails-architecture-proposal.md §2「主キー」= Laravel実装を踏襲し全モデルUUID）。
# migration生成時に毎回 `id: :uuid` を書かずに済むよう、ここでデフォルト化する。
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
