# CustomerStatus / OrderStatus 共通の「システム定義行は削除・code変更不可」ガード。
# app/models/system_role.rb の prevent_system_role_destroy / system_role_name_cannot_change と
# 同じパターンをステータスマスタ2種で再利用するために切り出した（04 R2タスク4）。
module SystemManagedStatus
  extend ActiveSupport::Concern

  included do
    include TracksUser
    include Auditable

    validates :code, presence: true, uniqueness: true, length: { maximum: 100 }
    validates :label, presence: true, length: { maximum: 255 }

    validate :code_cannot_change_for_system_record, if: :persisted?

    before_destroy :prevent_system_record_destroy

    scope :active, -> { where(is_active: true) }
    scope :ordered, -> { order(:sort_order) }
  end

  private

  def code_cannot_change_for_system_record
    return unless is_system? && will_save_change_to_code?

    errors.add(:code, "はシステム定義のため変更できません")
  end

  def prevent_system_record_destroy
    return unless is_system?

    errors.add(:base, "システム定義のステータスは削除できません")
    throw :abort
  end
end
