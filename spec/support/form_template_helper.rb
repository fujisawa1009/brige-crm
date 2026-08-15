# request spec 共通ヘルパー: 商材に「顧客情報→案件情報」の2ステップ申込フォームを組み立てる
# （04 R3。動的マルチステップ・動的マッピング・選択オプション(product_option_ids)の3点を
# 一度に検証できる最小構成）。
module FormTemplateHelper
  def build_two_step_form_template(product:, options: [])
    template = create(:form_template, product: product)

    step1 = create(:form_step, form_template: template, step_number: 1, name: "顧客情報")
    create(:form_field, form_step: step1, field_key: "customer_name", label: "顧客名",
           field_type: "text", target_table: "customer", target_column: "name", required: true, sort_order: 1)
    create(:form_field, form_step: step1, field_key: "customer_email", label: "メールアドレス",
           field_type: "text", target_table: "customer", target_column: "email", required: false, sort_order: 2)
    create(:form_field, form_step: step1, field_key: "store_name", label: "店舗名",
           field_type: "text", target_table: "store", target_column: "store_name", required: true, sort_order: 3)

    step2 = create(:form_step, form_template: template, step_number: 2, name: "案件情報")
    create(:form_field, form_step: step2, field_key: "order_remarks", label: "備考",
           field_type: "textarea", target_table: "order", target_column: "remarks", required: false, sort_order: 1)
    if options.any?
      create(:form_field, form_step: step2, field_key: "order_options", label: "オプション",
             field_type: "checkbox_group", target_table: "order", target_column: "product_option_ids",
             required: false, sort_order: 2)
    end

    template
  end
end

RSpec.configure do |config|
  config.include FormTemplateHelper, type: :request
end
