# BRIDGE_PLUS 申込フォームの初期テンプレート投入（04 R3残・form-template-mapping.md §2/§9）。
# StatusSeeder/RoleSeederと同じ冪等パターンで db/seeds.rb と運用時の再実行の両方から呼べる。
#
# 出典: form-template-mapping.md §9-3 フィールド別突合表（67件。field_key/target_table/target_column/
# field_typeは同表を正とする。§9-1の型読替（yes_no系はboolean不可→select、tel/emailはtext、number→integer、
# dateは実カラムがstring(50)のため文字列保存になるが列挙どおりdateのまま）を反映済み）。
#
# 【要確認】consent_status/business_proof/elderly_consent/business_auth_doc/applicant_type の選択肢は、
# form-template-mapping.md §3で「要確認」と明記された業務未確定事項。同書記載の「選択肢案」を暫定値として
# 投入する（applicant_typeのみColumn.md §8の3値を採用。§3の2値案とは差分あり）。本番運用開始前に
# 業務側の最終確認が必要（該当箇所に個別コメントあり）。yes_noは§3で「確定」済みのためそのまま採用。
#
# 冪等性: 既に投入済みのField（form_step_id+field_key一致）は上書きしない（フォームビルダーでの手動編集を
# 尊重する。RoleSeederのように属性を毎回同期する設計ではなく「無ければ作る」投入専用）。
class BridgePlusFormTemplateSeeder
  PRODUCT_CODE = "BRIDGE_PLUS"

  PREFECTURES = %w[
    北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県
    新潟県 富山県 石川県 福井県 山梨県 長野県 岐阜県 静岡県 愛知県 三重県 滋賀県 京都府 大阪府 兵庫県
    奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県
    熊本県 大分県 宮崎県 鹿児島県 沖縄県
  ].freeze

  # OptionGroup key => { label:, values: [[value, label], ...] }
  # 出典: form-template-mapping.md §3。yes_noのみ「確定」、他は「要確認」（コメント参照）。
  OPTION_GROUPS = {
    "prefecture" => {
      label: "都道府県",
      values: PREFECTURES.map { |name| [ name, name ] }
    },
    "payment_method" => {
      label: "お支払方法",
      # Column.md §10 の表記（預金口座振替／クレジット）を採用。§3の「クレジットカード／口座振替」は同義の
      # 案として残るが、DB設計側の表記に揃える。
      values: [ [ "預金口座振替", "預金口座振替" ], [ "クレジット", "クレジット" ] ]
    },
    "yes_no" => {
      label: "はい/いいえ（共通）",
      values: [ [ "はい", "はい" ], [ "いいえ", "いいえ" ] ]
    },
    "applicant_type" => {
      label: "申込者区分",
      # 【要確認】Column.md §8 の3値（法人/個人事業主/個人）を採用。form-template-mapping.md §3 の
      # 「選択肢案」は法人/個人事業主の2値のみで差分あり。業務側の最終確認が必要。
      values: [ [ "法人", "法人" ], [ "個人事業主", "個人事業主" ], [ "個人", "個人" ] ]
    },
    "consent_status" => {
      label: "同意状況",
      # 【要確認】form-template-mapping.md §3 の「選択肢案」をそのまま暫定採用。
      values: [ [ "同意", "同意" ], [ "同意なし", "同意なし" ], [ "確認中", "確認中" ] ]
    },
    "business_proof" => {
      label: "事業証明書",
      # 【要確認】form-template-mapping.md §3 の「選択肢案」をそのまま暫定採用。
      values: [ [ "あり", "あり" ], [ "なし", "なし" ] ]
    },
    "elderly_consent" => {
      label: "高齢者同意書",
      # 【要確認】form-template-mapping.md §3 の「選択肢案」をそのまま暫定採用。
      values: [ [ "あり", "あり" ], [ "なし", "なし" ], [ "該当なし", "該当なし" ] ]
    },
    "business_auth_doc" => {
      label: "業務権限証明書",
      # 【要確認】form-template-mapping.md §3 の「選択肢案」をそのまま暫定採用。
      values: [ [ "あり", "あり" ], [ "なし", "なし" ], [ "該当なし", "該当なし" ] ]
    }
  }.freeze

  # 各フィールドの choices は上記 OPTION_GROUPS の key を参照する（FormField は現行実装では
  # OptionGroup を直接参照せずinput_options.choicesにインライン保持するため、下記STEPSの組み立て時に
  # このkeyからOPTION_GROUPS[key][:values]を展開してinput_optionsへ複製する。form-template-mapping.md §3）。
  STEPS = [
    {
      name: "基本情報（お客様・店舗）",
      fields: [
        { key: "customer_name", label: "お名前（会社名）", target_table: "customer", target_column: "name", type: "text" },
        { key: "customer_email", label: "メールアドレス", target_table: "customer", target_column: "email", type: "text" },
        { key: "store_name", label: "店舗名", target_table: "store", target_column: "store_name", type: "text" },
        { key: "store_name_kana", label: "店舗名（カナ）", target_table: "store", target_column: "store_name_kana", type: "text" },
        { key: "postal_code", label: "郵便番号", target_table: "store", target_column: "postal_code", type: "text" },
        { key: "prefecture", label: "都道府県", target_table: "store", target_column: "prefecture", type: "select", option_group: "prefecture" },
        { key: "city", label: "市区町村", target_table: "store", target_column: "city", type: "text" },
        { key: "town", label: "町名・番地", target_table: "store", target_column: "town", type: "text" },
        { key: "address_detail", label: "建物名・部屋番号", target_table: "store", target_column: "address_detail", type: "text" },
        { key: "phone_number", label: "電話番号", target_table: "store", target_column: "phone_number", type: "text" },
        { key: "fax_number", label: "FAX番号", target_table: "store", target_column: "fax_number", type: "text" },
        { key: "payment_method", label: "お支払方法", target_table: "order", target_column: "payment_method", type: "select", option_group: "payment_method" }
      ]
    },
    {
      name: "確認コール",
      fields: [
        { key: "confirm_call_preferred_date", label: "確認コール連絡希望日", target_table: "order", target_column: "confirm_call_preferred_date", type: "date" },
        { key: "confirm_call_time", label: "確認コール架電時間", target_table: "order", target_column: "confirm_call_time", type: "text" },
        { key: "confirm_call_contact_name", label: "確認コール担当者名", target_table: "order", target_column: "confirm_call_contact_name", type: "text" },
        { key: "confirm_call_remarks", label: "確認コール備考", target_table: "order", target_column: "confirm_call_remarks", type: "textarea" }
      ]
    },
    {
      name: "同意・書類",
      fields: [
        { key: "consent_status", label: "同意状況", target_table: "order", target_column: "consent_status", type: "select", option_group: "consent_status" },
        { key: "consent_rep_age", label: "同意時 代表者年齢", target_table: "order", target_column: "consent_rep_age", type: "integer" },
        { key: "consent_contact_age", label: "同意時 担当者年齢", target_table: "order", target_column: "consent_contact_age", type: "integer" },
        { key: "business_proof", label: "事業証明書", target_table: "order", target_column: "business_proof", type: "select", option_group: "business_proof" },
        { key: "elderly_consent", label: "高齢者同意書", target_table: "order", target_column: "elderly_consent", type: "select", option_group: "elderly_consent" },
        { key: "business_auth_doc", label: "業務権限証明書", target_table: "order", target_column: "business_auth_doc", type: "select", option_group: "business_auth_doc" },
        { key: "paper_address_note", label: "用紙の送付先住所記載", target_table: "order", target_column: "paper_address_note", type: "text" }
      ]
    },
    {
      name: "設置先住所（信販用）",
      fields: [
        { key: "finance_postal_code", label: "設置先郵便番号", target_table: "order", target_column: "finance_postal_code", type: "text" },
        { key: "finance_prefecture", label: "設置先都道府県", target_table: "order", target_column: "finance_prefecture", type: "select", option_group: "prefecture" },
        { key: "finance_city", label: "設置先市区町村", target_table: "order", target_column: "finance_city", type: "text" },
        { key: "finance_town", label: "設置先町名・番地", target_table: "order", target_column: "finance_town", type: "text" },
        { key: "finance_address_detail", label: "設置先番地", target_table: "order", target_column: "finance_address_detail", type: "text" },
        { key: "finance_building", label: "設置先ビル名", target_table: "order", target_column: "finance_building", type: "text" },
        { key: "finance_phone", label: "設置先電話番号", target_table: "order", target_column: "finance_phone", type: "text" }
      ]
    },
    {
      name: "追加サービス",
      fields: [
        { key: "plus_applied", label: "Plus申込有無", target_table: "order", target_column: "plus_applied", type: "select", option_group: "yes_no" },
        { key: "citation_applied", label: "サイテーション申し込み", target_table: "order", target_column: "citation_applied", type: "select", option_group: "yes_no" },
        { key: "citation_count", label: "サイテーション申し込み数", target_table: "order", target_column: "citation_count", type: "integer" },
        { key: "citation_existing_serial", label: "サイテーション既存シリアル", target_table: "order", target_column: "citation_existing_serial", type: "text" },
        { key: "domestic_citation_plan", label: "国内サイテーションプラン", target_table: "order", target_column: "domestic_citation_plan", type: "text" },
        { key: "citation_plan", label: "サイテーションプラン", target_table: "order", target_column: "citation_plan", type: "text" },
        { key: "s_plan_cms", label: "Sプラン CMS", target_table: "order", target_column: "s_plan_cms", type: "select", option_group: "yes_no" },
        { key: "owlet_cms", label: "Owlet CMS", target_table: "order", target_column: "owlet_cms", type: "select", option_group: "yes_no" },
        { key: "onerank_cms", label: "Onerank CMS", target_table: "order", target_column: "onerank_cms", type: "select", option_group: "yes_no" },
        { key: "external_link_applied", label: "外部リンク申し込み", target_table: "order", target_column: "external_link_applied", type: "select", option_group: "yes_no" },
        { key: "external_link_count", label: "外部リンク申し込み数", target_table: "order", target_column: "external_link_count", type: "integer" },
        { key: "external_link_type", label: "外部リンクの型", target_table: "order", target_column: "external_link_type", type: "text" },
        { key: "gbp_multilingual", label: "GBPインバウンド多言語対策", target_table: "order", target_column: "gbp_multilingual", type: "select", option_group: "yes_no" },
        { key: "language_selection", label: "言語選択", target_table: "order", target_column: "language_selection", type: "text" },
        { key: "meo_existing_serial", label: "MEO既存シリアル", target_table: "order", target_column: "meo_existing_serial", type: "text" },
        { key: "infobiz_applied", label: "infoBiz申し込み", target_table: "order", target_column: "infobiz_applied", type: "select", option_group: "yes_no" },
        { key: "meo_premium_applied", label: "MEOプレミアム強化プラン申し込み", target_table: "order", target_column: "meo_premium_applied", type: "select", option_group: "yes_no" },
        { key: "google_ads_applied", label: "Google広告申し込み", target_table: "order", target_column: "google_ads_applied", type: "select", option_group: "yes_no" },
        { key: "google_ads_count", label: "Google広告申し込み数", target_table: "order", target_column: "google_ads_count", type: "integer" },
        { key: "google_review_display", label: "Google口コミ表示", target_table: "order", target_column: "google_review_display", type: "select", option_group: "yes_no" },
        { key: "review_heading", label: "口コミ表示の見出し名", target_table: "order", target_column: "review_heading", type: "text" },
        { key: "reservation_system", label: "予約システム", target_table: "order", target_column: "reservation_system", type: "select", option_group: "yes_no" },
        { key: "portal_site_applied", label: "ポータルサイト掲載の申し込み", target_table: "order", target_column: "portal_site_applied", type: "select", option_group: "yes_no" },
        { key: "bridge_migration", label: "Bridge移行", target_table: "order", target_column: "bridge_migration", type: "select", option_group: "yes_no" },
        { key: "bridge_migration_order_number", label: "Bridge移行案件番号", target_table: "order", target_column: "bridge_migration_order_number", type: "text" }
      ]
    },
    {
      name: "契約者詳細情報",
      fields: [
        # 設計上のtarget_columnは customers.name_kana だが実カラムは無く contractor_name_kana に読み替え
        # （form-template-mapping.md §9-3 判定B。列名差異のみで保存先自体は実在）。
        { key: "customer_name_kana", label: "契約者名（カナ）", target_table: "customer", target_column: "contractor_name_kana", type: "text" },
        { key: "applicant_type", label: "申込者区分", target_table: "customer", target_column: "applicant_type", type: "select", option_group: "applicant_type" },
        { key: "customer_postal_code", label: "契約者郵便番号", target_table: "customer", target_column: "postal_code", type: "text" },
        { key: "customer_prefecture", label: "契約者都道府県", target_table: "customer", target_column: "prefecture", type: "select", option_group: "prefecture" },
        { key: "customer_city", label: "契約者市区町村", target_table: "customer", target_column: "city", type: "text" },
        { key: "customer_town", label: "契約者町名・番地", target_table: "customer", target_column: "town", type: "text" },
        { key: "customer_address_detail", label: "契約者建物名", target_table: "customer", target_column: "address_detail", type: "text" },
        { key: "customer_phone", label: "日中のご連絡先電話番号", target_table: "customer", target_column: "phone", type: "text" },
        { key: "customer_mobile", label: "携帯電話番号", target_table: "customer", target_column: "mobile_phone", type: "text" }
      ]
    },
    {
      name: "店舗詳細情報",
      fields: [
        { key: "business_hours_1", label: "営業時間1", target_table: "store", target_column: "business_hours_1", type: "text" },
        { key: "business_hours_2", label: "営業時間2", target_table: "store", target_column: "business_hours_2", type: "text" },
        { key: "regular_holiday", label: "定休日", target_table: "store", target_column: "regular_holiday", type: "text" }
      ]
    }
  ].freeze

  def self.call
    new.call
  end

  def call
    seed_option_groups
    seed_form_template
  end

  private

  def seed_option_groups
    OPTION_GROUPS.each do |key, definition|
      group = OptionGroup.find_or_create_by!(key: key) do |g|
        g.label = definition[:label]
        g.is_active = true
      end

      definition[:values].each_with_index do |(value, label), index|
        option = group.option_values.find_or_initialize_by(value: value)
        next if option.persisted?

        option.label = label
        option.sort_order = index + 1
        option.is_active = true
        option.save!
      end
    end
  end

  def seed_form_template
    product = Product.find_or_create_by!(code: PRODUCT_CODE) do |p|
      p.name = "BRIDGE_PLUS"
      p.is_active = true
    end

    template = FormTemplate.find_or_create_by!(product: product) do |t|
      t.name = "BRIDGE_PLUS 申込フォーム"
      t.is_active = true
    end

    STEPS.each_with_index do |step_def, step_index|
      step = FormStep.find_or_create_by!(form_template: template, step_number: step_index + 1) do |s|
        s.name = step_def[:name]
      end

      step_def[:fields].each_with_index do |field_def, field_index|
        seed_field(step, field_def, field_index)
      end
    end
  end

  def seed_field(step, field_def, index)
    field = step.form_fields.find_or_initialize_by(field_key: field_def[:key])
    return if field.persisted?

    field.label = field_def[:label]
    field.field_type = field_def[:type]
    field.target_table = field_def[:target_table]
    field.target_column = field_def[:target_column]
    field.required = false
    field.sort_order = index + 1
    field.editable_by_tier = [ "sales_representative" ]
    field.input_options = choices_for(field_def[:option_group])
    field.validation_rules = {}
    field.save!
  end

  def choices_for(option_group_key)
    return {} if option_group_key.blank?

    { "choices" => OPTION_GROUPS.fetch(option_group_key).fetch(:values) }
  end
end
