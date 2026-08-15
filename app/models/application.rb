# 申込トランザクション（04 R3タスク5・Laravel移行元 Application モデル）。
#
# 営業担当者ログイン後の動的マルチステップの進行状態そのもの。ステップごとの回答は
# form_data(jsonb)に「field_key => 回答値」で蓄積し、完了時にForm::ApplicationSubmissionServiceが
# 1トランザクションでCustomer + Store + Order（+ 選択オプション）を生成してcustomer_id/store_id/
# order_idを埋める。form_templateはproduct経由で解決する（バージョニング機構が無いため
# form_template_idを別途持たせない。将来テンプレートを版管理する要件が出たら見直す）。
#
# 注意: form_dataには氏名・連絡先等のPIIが含まれうるため、Auditableは意図的にincludeしない
# （Auditableをそのまま使うとTRACKED_FIELDSにform_dataを含めない限り差分は残らないが、
# 誤って追加した場合の事故を避けるため、完了イベントはForm::ApplicationsController側で
# 必要最小限の項目だけをAuditLogへ明示的に記録する）。
# == Schema Information
#
# Table name: applications
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  current_step_number     :integer          default(1), not null
#  form_data               :jsonb            not null
#  status                  :string           default("in_progress"), not null
#  token                   :string(64)       not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  agency_id               :uuid             not null
#  created_by_id           :uuid
#  customer_id             :uuid
#  order_id                :uuid
#  product_id              :uuid             not null
#  sales_representative_id :uuid             not null
#  store_id                :uuid
#  updated_by_id           :uuid
#
# Indexes
#
#  index_applications_on_sales_representative_id  (sales_representative_id)
#  index_applications_on_status                   (status)
#  index_applications_on_token                    (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id) ON DELETE => restrict
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (customer_id => customers.id) ON DELETE => nullify
#  fk_rails_...  (order_id => orders.id) ON DELETE => nullify
#  fk_rails_...  (product_id => products.id) ON DELETE => restrict
#  fk_rails_...  (sales_representative_id => sales_representatives.id) ON DELETE => restrict
#  fk_rails_...  (store_id => stores.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id)
#
class Application < ApplicationRecord
  STATUSES = %w[in_progress completed].freeze

  belongs_to :sales_representative
  belongs_to :agency
  belongs_to :product
  belongs_to :customer, optional: true
  belongs_to :store, optional: true
  belongs_to :order, optional: true

  before_validation :assign_token, on: :create

  validates :token, presence: true, uniqueness: true, length: { is: 64 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :current_step_number, numericality: { only_integer: true, greater_than: 0 }

  scope :in_progress, -> { where(status: "in_progress") }

  def form_template
    product.form_template
  end

  def completed?
    status == "completed"
  end

  private

  def assign_token
    return if token.present?

    self.token = loop do
      candidate = SecureRandom.hex(32) # 64桁（Laravel Application#token踏襲）
      break candidate unless Application.exists?(token: candidate)
    end
  end
end
