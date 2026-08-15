# 動的マルチステップの1画面分（04 R3タスク3・4）。step_numberが表示順とForm::ApplicationsController
# のルーティング上のステップ番号を兼ねる（Laravel現行 routes/form.php の step/{n} を踏襲）。
# == Schema Information
#
# Table name: form_steps
#
#  id               :uuid             not null, primary key
#  name             :string           not null
#  step_number      :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :uuid
#  form_template_id :uuid             not null
#  updated_by_id    :uuid
#
# Indexes
#
#  index_form_steps_on_form_template_id_and_step_number  (form_template_id,step_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (form_template_id => form_templates.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id)
#
class FormStep < ApplicationRecord
  include TracksUser
  include Auditable

  belongs_to :form_template

  has_many :form_fields, -> { order(:sort_order) }, dependent: :destroy, inverse_of: :form_step
  accepts_nested_attributes_for :form_fields, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true, length: { maximum: 255 }
  validates :step_number, presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: :form_template_id }
end
