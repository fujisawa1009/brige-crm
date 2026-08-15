require "rails_helper"

# 04 R3タスク5: 申込トランザクション本体（Laravel移行元 Application）のtoken生成を確認する。
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
RSpec.describe Application, type: :model do
  describe "#assign_token" do
    it "64桁のtokenを自動生成する" do
      application = create(:application)
      expect(application.token.length).to eq(64)
    end

    it "既存のtokenを上書きしない" do
      application = create(:application, token: "a" * 64)
      expect(application.token).to eq("a" * 64)
    end
  end

  describe "#form_template" do
    it "productのform_templateを返す" do
      product = create(:product)
      form_template = create(:form_template, product: product)
      application = create(:application, product: product)

      expect(application.form_template).to eq(form_template)
    end
  end
end
