# 作成者/更新者の自動記録（04 R0-8。ftlogに直接の相当concernは無いが、Current +
# created_by/updated_by自動セットという要件はTracksUser相当としてR0で新設する）。
#
# includeするモデルは created_by_id / updated_by_id (uuid, users.idへのFK) カラムを持つこと。
# Current.user が無いコンテキスト（コンソール・マイグレーション直後のseed等）ではnilのままにし、
# 例外にはしない（バッチ処理はCurrent.set(user: ...) { ... }で明示すること）。
module TracksUser
  extend ActiveSupport::Concern

  included do
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :updated_by, class_name: "User", optional: true

    before_create { self.created_by_id ||= Current.user&.id }
    before_save   { self.updated_by_id = Current.user.id if Current.user }
  end
end
