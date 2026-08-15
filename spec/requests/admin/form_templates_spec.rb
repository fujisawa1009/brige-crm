require "rails_helper"

# 04 R3タスク6: フォームビルダー（FormTemplate 1─* FormStep 1─* FormField をネスト属性で一括編集）。
# admin/form_templatesは商材マスタ以上に内部運用寄りの設定物のため、RoleSeederで実務運用者専有に
# している（app/services/role_seeder.rb R3_FORM_BUILDER_CONTROLLERS参照）。代理店/代理店グループ
# ロールには参照権限すら渡していないため、index等も含めて403になることを確認する。
RSpec.describe "Admin::FormTemplates", type: :request, seed_permission_catalog: true, system_authorization: true do
  let!(:product) { create(:product) }

  describe "実務運用者" do
    let!(:staff_user) { user_with_role("実務運用者") }

    before { sign_in_with_otp!(staff_user) }

    it "一覧・詳細を閲覧できる" do
      form_template = create(:form_template, product: product)

      get admin_form_templates_path
      expect(response).to have_http_status(:ok)

      get admin_form_template_path(form_template)
      expect(response).to have_http_status(:ok)
    end

    it "ステップ・フィールドをネスト属性で同時作成できる" do
      expect do
        post admin_form_templates_path, params: {
          form_template: {
            product_id: product.id,
            name: "申込フォームA",
            is_active: "1",
            form_steps_attributes: {
              "0" => {
                step_number: 1,
                name: "顧客情報",
                form_fields_attributes: {
                  "0" => {
                    field_key: "customer_name",
                    label: "顧客名",
                    field_type: "text",
                    target_table: "customer",
                    target_column: "name",
                    required: "1",
                    sort_order: 1,
                    editable_by_tier: [ "sales_representative" ]
                  }
                }
              }
            }
          }
        }
      end.to change(FormTemplate, :count).by(1)
        .and change(FormStep, :count).by(1)
        .and change(FormField, :count).by(1)

      expect(response).to redirect_to(admin_form_template_path(FormTemplate.last))
      field = FormField.last
      expect(field.target_table).to eq("customer")
      expect(field.editable_by_tier).to eq([ "sales_representative" ])
    end

    it "既存テンプレートへフィールドを追加し、別のフィールドを削除できる（動的フィールド追加・削除）" do
      form_template = create(:form_template, product: product)
      step = create(:form_step, form_template: form_template, step_number: 1)
      keep_field   = create(:form_field, form_step: step, field_key: "keep", sort_order: 1)
      remove_field = create(:form_field, form_step: step, field_key: "remove", sort_order: 2)

      patch admin_form_template_path(form_template), params: {
        form_template: {
          name: form_template.name,
          form_steps_attributes: {
            "0" => {
              id: step.id,
              step_number: step.step_number,
              name: step.name,
              form_fields_attributes: {
                "0" => { id: keep_field.id, field_key: "keep", label: "維持", field_type: "text",
                          target_table: "customer", target_column: "name", sort_order: 1 },
                "1" => { id: remove_field.id, _destroy: "1" },
                "2" => { field_key: "added", label: "追加項目", field_type: "text",
                          target_table: "customer", target_column: "phone", sort_order: 3 }
              }
            }
          }
        }
      }

      expect(response).to redirect_to(admin_form_template_path(form_template))
      expect(step.form_fields.pluck(:field_key)).to contain_exactly("keep", "added")
    end

    it "テンプレートを削除できる" do
      form_template = create(:form_template, product: product)

      expect { delete admin_form_template_path(form_template) }.to change(FormTemplate, :count).by(-1)
    end

    it "無効なJSONの選択肢はエラーになる" do
      form_template = create(:form_template, product: product)

      patch admin_form_template_path(form_template), params: {
        form_template: {
          name: form_template.name,
          form_steps_attributes: {
            "0" => {
              step_number: 1, name: "ステップ1",
              form_fields_attributes: {
                "0" => { field_key: "broken", label: "壊れた選択肢", field_type: "select",
                          target_table: "customer", target_column: "name", sort_order: 1,
                          input_options_json: "not json" }
              }
            }
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "代理店/代理店グループロールは参照すら許可されない" do
    it "代理店ユーザーは一覧が403" do
      agency_user = user_with_role("代理店用", agency: create(:agency))
      sign_in_with_otp!(agency_user)

      get admin_form_templates_path
      expect(response).to have_http_status(:forbidden)
    end

    it "代理店グループユーザーは一覧が403" do
      group_user = user_with_role("代理店グループ用", agency_group: create(:agency_group))
      sign_in_with_otp!(group_user)

      get admin_form_templates_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
