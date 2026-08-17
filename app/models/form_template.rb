# 申込フォーム定義（04 R3タスク3・03§5「Product 1─1 FormTemplate」）。P2拡張後仕様の実体は
# 配下のFormStep/FormFieldが持つ（target_table/target_column/editable_by_tier/lock_after_status）ため、
# このモデル自体は薄い（商材との1-1関係＋有効フラグのみ）。
#
# 管理画面のフォームビルダー（Admin::FormTemplatesController）はステップ・フィールドを
# ネスト属性でまとめて保存する（04 R3タスク6「動的フィールド追加・並び替え程度で十分」に対応する
# 最小構成。専用のFormStep/FormField単体CRUD画面は作らない）。
# == Schema Information
#
# Table name: form_templates
#
#  id            :uuid             not null, primary key
#  is_active     :boolean          default(TRUE), not null
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :uuid
#  product_id    :uuid             not null
#  updated_by_id :uuid
#
# Indexes
#
#  index_form_templates_on_product_id  (product_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (product_id => products.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class FormTemplate < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :product

  has_many :form_steps, -> { order(:step_number) }, dependent: :destroy, inverse_of: :form_template
  accepts_nested_attributes_for :form_steps, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true, length: { maximum: 255 }
  validates :product_id, uniqueness: true

  # R3レビュー指摘（バグ修正）: FormStep/FormFieldはdependent: :destroyでFormTemplate削除に連動して
  # 消えるため、対象商材で進行中のApplication（Form::ApplicationsController#set_form_stepや
  # Form::ApplicationSubmissionService#all_fieldsがform_template.form_stepsへ依存）が残っていると、
  # 申込者の次のリクエストでNoMethodError（未捕捉の500）になる。Product#applicationsの
  # dependent: :restrict_with_errorと同様のガードをFormTemplate単独削除にも効かせる。
  before_destroy :prevent_destroy_with_in_progress_applications

  scope :active, -> { where(is_active: true) }

  private

  def prevent_destroy_with_in_progress_applications
    return unless product.applications.in_progress.exists?

    errors.add(:base, "進行中の申込があるため削除できません。無効化(is_active=false)をご利用ください。")
    throw :abort
  end
end
