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

    # R3レビュー指摘（バグ修正）: 進行中のApplicationを巻き込んだ削除を拒否する
    # （app/models/form_template.rb#prevent_destroy_with_in_progress_applications）。
    it "進行中の申込がある商材のテンプレートは削除できない" do
      form_template = create(:form_template, product: product)
      sales_representative = create(:sales_representative, agency: create(:agency))
      create(:application, product: product, sales_representative: sales_representative,
             agency: sales_representative.agency, status: "in_progress")

      expect { delete admin_form_template_path(form_template) }.not_to change(FormTemplate, :count)
      expect(response).to redirect_to(admin_form_template_path(form_template))
      follow_redirect!
      expect(response.body).to include("進行中の申込があるため削除できません")
    end

    # 非エンジニア向けUI刷新（決定者確定仕様）: 選択肢(choices)・検証ルール(validation_rules)は
    # 生JSON textareaではなく行入力→送信直前にStimulus（choice-list/validation-rule-list
    # controller）がJSONへ組み立てる構成に変わったが、request specはJSを実行しないため、
    # 組み立て済みのJSON文字列をinput_options_json/validation_rules_jsonへ直接POSTすることで
    # ブラウザでの送信を再現する。保存後、編集画面を開いたときに行として正しく復元表示される
    # （= choice_row/validation_rule_rowパーシャルが保存済みの値をvalue属性へ描画する）ことを確認する。
    it "選択肢・検証ルールの行入力（JSON化済み）を保存し、編集画面で行として復元表示される" do
      form_template = create(:form_template, product: product)
      step = create(:form_step, form_template: form_template, step_number: 1)

      patch admin_form_template_path(form_template), params: {
        form_template: {
          name: form_template.name,
          form_steps_attributes: {
            "0" => {
              id: step.id, step_number: step.step_number, name: step.name,
              form_fields_attributes: {
                "0" => {
                  field_key: "plan", label: "プラン", field_type: "select",
                  target_table: "order", target_column: "product_initial_fee_id", sort_order: 1,
                  input_options_json: '{"choices":[["plan_a","プランA"],["plan_b","プランB"]]}',
                  validation_rules_json: '{"max_length":100}'
                }
              }
            }
          }
        }
      }

      expect(response).to redirect_to(admin_form_template_path(form_template))
      field = FormField.last
      expect(field.input_options).to eq({ "choices" => [ [ "plan_a", "プランA" ], [ "plan_b", "プランB" ] ] })
      expect(field.validation_rules).to eq({ "max_length" => 100 })

      get edit_admin_form_template_path(form_template)
      expect(response).to have_http_status(:ok)

      doc = Nokogiri::HTML(response.body)
      choice_rows = doc.css("[data-choice-list-target='row']")
      restored_choices = choice_rows.map do |row|
        [ row.at_css("[data-role='key']")["value"], row.at_css("[data-role='label']")["value"] ]
      end
      expect(restored_choices).to include([ "plan_a", "プランA" ], [ "plan_b", "プランB" ])

      rule_rows = doc.css("[data-validation-rule-list-target='row']")
      restored_rules = rule_rows.map do |row|
        [ row.at_css("[data-role='type'] option[selected]")&.[]("value"), row.at_css("[data-role='value']")["value"] ]
      end
      expect(restored_rules).to include([ "max_length", "100" ])
    end

    # 非エンジニア向けUI刷新（決定者確定仕様）: target_table（反映先モデル）を切り替えたとき、
    # target_column（反映先の項目）の選択肢をサーバ往復なしで絞り込むtarget-column-filter
    # Stimulusコントローラが読む、4テーブル分の許可カラム一覧JSONがHTMLへ正しく埋め込まれていること。
    it "target_column動的絞り込み用の4テーブル分カラム一覧JSONがHTMLに埋め込まれる" do
      form_template = create(:form_template, product: product)

      get new_admin_form_template_path
      expect(response).to have_http_status(:ok)

      doc = Nokogiri::HTML(response.body)
      node = doc.at_css("[data-target-column-filter-columns-by-table-value]")
      expect(node).to be_present

      columns_by_table = JSON.parse(node["data-target-column-filter-columns-by-table-value"])
      expect(columns_by_table.keys).to match_array(%w[customer store order order_work_detail])
      expect(columns_by_table["customer"]).to include([ "契約者名または法人名", "name" ])
      expect(columns_by_table["order"]).to include([ "オプション（複数選択）", "product_option_ids" ])
      expect(columns_by_table["order"]).to include([ "初期費用プラン", "product_initial_fee_id" ])
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
