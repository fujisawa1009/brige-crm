# AILINK商材 申込フォームの初期テンプレート投入（2026-08-21 CEO指示・出典:
# private/36.ジャスミン資料/新商材フォーム/FIX_浅賀確認用_選択フォーム要件整理.xlsx の P2〜P11シート）。
# FIX版の色分け規約: A列黄色=別ページで入力済みの表示専用（入力フィールドにしない）、
# A列緑色=フォームでは入力しない契約後カラム（全て既存スキーマに実在。管理画面側の業務入力）。
# BridgePlusFormTemplateSeeder と同じ冪等パターン（「無ければ作る」投入専用。フォームビルダーでの
# 手動編集を尊重し、既存フィールドは上書きしない。マスタ由来の選択肢のみ毎回同期）。
#
# シート上の商材名は P2「商材」ラジオの選択値 AILINK を採用（要件シート表題は「Brige_plus 選択フォーム」、
# 議事録は「新プラン Brige_plus」のため、商材=AILINK／プラン=Brige_plus と解釈。名称は要CEO確認）。
#
# 【シートとの既知の差分（現行フォーム機構の制約。解消はR5-14 入力チェック設定／G-5 フォームビルダー拡張）】
# - 条件付き必須（法人選択時の代表者名・資本金、多言語対策あり時の言語選択、Facebook保有時のID/PASS等）は
#   機構未対応のため required: false で投入（3段階必須は R5 の InputCheckRule で実装予定）。
# - 「ご契約者情報と同様」チェックによる住所コピー・P2メールのP3自動反映・オプション①のデフォルト
#   チェック＆編集不可は未対応（Stimulus拡張が必要。現状は通常入力欄として投入）。
# - P5 請求書送付先の都道府県〜番地は customers.invoice_address 1列（string 500）のため1欄に集約。
# - P2 受注日・プランの自動入力は Form::ApplicationSubmissionService#assign_auto_values! が担う。
# - P10（営業担当情報）は全項目が表示専用（P1ログイン・P2アポインターコードの反映）のためステップにしない
#   （アポインター担当者名のコードからの自動解決は表示側の対応＝未実装）。
# - P11（最終確認画面）のうち入力項目（同意時年齢2つ）のみ「最終確認」ステップとして投入。
#   重説レ点=R5-13の顧客導線組込、電子署名=R5-14、申込完了ボタン=既存の確認画面submitが担う。
class AilinkFormTemplateSeeder
  PRODUCT_CODE = "AILINK"

  # P2 初期費用（BRIDGE_PLUSと同一の5値。0円は代理店負担）
  INITIAL_FEES = [
    [ "0円", 0, 1 ],
    [ "30,000円", 30_000, 2 ],
    [ "50,000円", 50_000, 3 ],
    [ "100,000円", 100_000, 4 ],
    [ "150,000円", 150_000, 5 ]
  ].freeze

  # OptionGroup key => { label:, values: }。prefecture は BridgePlusFormTemplateSeeder と共通。
  # 値はすべて要件シートの「選択表示・入力例」列の文言をそのまま採用。
  OPTION_GROUPS = {
    "prefecture" => {
      label: "都道府県",
      values: BridgePlusFormTemplateSeeder::PREFECTURES.map { |name| [ name, name ] }
    },
    "contractor_type" => {
      # 既存の applicant_type グループ（法人/個人事業主/個人の3値）とは別に、シートどおりの2値を持つ
      # （AILINKフォームは「法人 or 個人事業主」のラジオ。既存3値との統合要否は要CEO確認）。
      label: "ご契約者区分",
      values: [ [ "法人", "法人" ], [ "個人事業主", "個人事業主" ] ]
    },
    "inventory_type" => {
      label: "在庫区分",
      values: [ [ "新規", "新規" ], [ "増設", "増設" ] ]
    },
    "discount_option" => {
      # P2 オプション②。正式名称・適用条件は要件シート No.4/5（長期割引。契約更新月以外の解約時は
      # 割引総額を解約金として請求）。Q-46: 選択値により利用規約を自動切替（R5実装）。
      label: "割引オプション",
      values: [
        [ "割引なし", "割引なし" ],
        [ "長期割引（税込11,000円）", "長期割引（税込11,000円）" ],
        [ "長期割引（税込22,000円）", "長期割引（税込22,000円）" ]
      ]
    },
    "invoice_destination" => {
      label: "請求書送付先",
      values: [
        [ "契約者住所と同一", "契約者住所と同一" ],
        [ "設置先住所と同一", "設置先住所と同一" ],
        [ "異なる請求書先", "異なる請求書先" ]
      ]
    },
    "bundled_billing" => {
      # 「する」場合のみ選択（未選択=なし）。複数件口の1件目は空白・2件目以降「する」で登録する運用
      # （P5補足）。「する」の案件は電子サイン時にクレカ登録画面を経由しない（R5決済分岐で参照）。
      label: "おまとめ請求",
      values: [ [ "する", "する" ] ]
    },
    "barrier_free" => {
      label: "バリアフリーの有無",
      values: [ [ "有", "有" ], [ "無", "無" ] ]
    },
    "wifi_available" => {
      label: "Wi-Fiの有無",
      values: [ [ "なし", "なし" ], [ "無料Wi-Fi", "無料Wi-Fi" ], [ "有料Wi-Fi", "有料Wi-Fi" ] ]
    },
    "business_type" => {
      label: "業態",
      values: [ [ "店舗型", "店舗型" ], [ "出張型", "出張型" ], [ "店舗型＆出張型", "店舗型＆出張型" ] ]
    },
    "availability" => {
      label: "あり/なし（共通）",
      values: [ [ "あり", "あり" ], [ "なし", "なし" ] ]
    },
    "language" => {
      label: "言語選択",
      values: %w[英語 中国語 韓国語 スペイン語 フランス語 ドイツ語 イタリア語 ポルトガル語 オランダ語 ロシア語 アラビア語].map { |l| [ l, l ] }
    },
    "gbp_possession" => {
      label: "Googleビジネスアカウントの所持状況",
      values: [ [ "お客様所持", "お客様所持" ], [ "新規取得", "新規取得" ], [ "所持者不明", "所持者不明" ] ]
    },
    "permission_known" => {
      label: "オーナー権限",
      values: [ [ "わかる", "わかる" ], [ "不明", "不明" ] ]
    },
    "gbp_grant_status" => {
      label: "GBP権限付与状況",
      values: [ [ "完了している", "完了している" ], [ "完了していない", "完了していない" ] ]
    },
    "sns_possession" => {
      label: "SNSアカウント所持状況",
      values: [
        [ "既に保有している", "既に保有している" ],
        [ "お客さまにて作成予定", "お客さまにて作成予定" ],
        [ "代行・補助希望", "代行・補助希望" ]
      ]
    },
    "contact_time_slot" => {
      label: "連絡が取りやすい時間帯",
      values: [ "いつでも", "9：00～12：00", "12：00～15：00", "15：00～18：00", "午前中", "午後", "その他" ].map { |v| [ v, v ] }
    },
    "contact_day" => {
      label: "連絡が取りやすい曜日",
      values: %w[いつでも 日 月 火 水 木 金 土 その他].map { |v| [ v, v ] }
    },
    "gbp_attribute_1" => {
      label: "GBP属性1",
      values: [ "女性経営者のビジネスと確認された", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_2" => {
      label: "GBP属性2",
      values: [ "車椅子対応のエレベーター", "車椅子対応のトイレ", "車椅子対応の入り口", "車椅子対応の座席",
                "車椅子対応の駐車場", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_3" => {
      label: "GBP属性3",
      values: [ "無料Wi-Fi", "有料Wi-Fi", "トイレありのお店", "バー併設", "子ども用の椅子", "子ども向き",
                "禁煙", "ジェンダーフリーのトイレ", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_4" => {
      label: "GBP属性4",
      values: [ "家族向き", "LGBTQ フレンドリー", "トランスジェンダー対応", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_5" => {
      label: "GBP属性5",
      values: [ "ケータリング", "ディナー", "デザート", "ランチ", "座席があるお店", "朝食", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_6" => {
      label: "GBP属性6",
      values: [ "スタッフの検温あり", "スタッフはマスク着用", "次の顧客の案内前にスタッフによる消毒",
                "要マスク", "要予約", "要検温", "レジカウンターでの飛沫防止措置", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_7" => {
      label: "GBP属性7",
      values: [ "スポーツ", "屋上の席あり", "暖炉がある", "生演奏あり", "飲み放題", "ライブパフォーマンス",
                "遊び場", "COVID-19の検査機関である", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_8" => {
      label: "GBP属性8",
      values: [ "アルコール", "カクテル", "キッズメニュー", "コーヒー", "サラダバーありのお店",
                "ドリンクのサービスタイムあり", "ハラール食", "ハードリカー", "ビール", "ベジタリアンメニュー",
                "ワイン", "小皿料理", "有機食材", "深夜の食事可", "点字メニュー", "食事の提供あり", "食べ放題",
                "食事のサービスタイムあり", "調理済み食品", "宅配", "店先受取可", "店舗内ショッピング可",
                "店舗受け取り可", "当日配達", "オイル交換", "レンタカー", "中古品の買い取り", "洗車",
                "ドライブスルー検査対応あり", "オンライン予約", "オンライン見積もり", "実店舗の営業", "補聴器",
                "オーガニック商品", "パスポート写真", "屋外でのサービス提供", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_9" => {
      label: "GBP属性9",
      values: [ "NFCモバイル決済", "クレジットカード[American Express]", "クレジットカード[Diners Club]",
                "クレジットカード[Discover]", "クレジットカード[JCB]", "クレジットカード[MasterCard]",
                "クレジットカード[VISA]", "クレジットカード[中国銀聯]", "デビットカード可", "小切手可",
                "現金のみ", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_10" => {
      label: "GBP属性10",
      values: [ "特定の患者の検査に対応", "紹介状が必要", "要予約", "予約可", "該当なし" ].map { |v| [ v, v ] }
    },
    "gbp_attribute_11" => {
      label: "GBP属性11",
      values: [ "イートイン", "テイクアウト", "テラス席がある", "ドライブスルー", "宅配", "店先受取可",
                "非接触デリバリー", "野外でのサービス提供", "店舗内ショッピング可", "店舗受け取り可",
                "当日配達", "該当なし" ].map { |v| [ v, v ] }
    }
  }.freeze

  # ステップ構成は要件シートのページ構成（P2〜P9）を踏襲する（P1ログインは既存のform認証、P6は欠番）。
  STEPS = [
    {
      name: "事前入力情報",
      fields: [
        { key: "inventory_type", label: "在庫区分", target_table: "customer", target_column: "inventory_type", type: "select", option_group: "inventory_type", required: true },
        { key: "product_initial_fee", label: "初期費用", target_table: "order", target_column: "product_initial_fee_id", type: "select", option_group: "product_initial_fee", required: true },
        # オプション①（MEOサービス/MEO外部リンク/サイテーション）。シートは「デフォルトでチェック・編集不可」
        # だが現行機構では通常のチェックボックス（選択肢は商材のProductOptionから動的導出）。
        { key: "product_options", label: "オプション①", target_table: "order", target_column: "product_option_ids", type: "checkbox_group", required: true },
        { key: "discount_option", label: "オプション②（割引）", target_table: "order", target_column: "discount_option", type: "select", option_group: "discount_option", required: true },
        { key: "customer_email", label: "お客様メールアドレス", target_table: "customer", target_column: "email", type: "text", required: true },
        # FIX版追加（P2）。営業担当と同一の場合は同じコードを入力する運用。営業担当者マスタとの照合は
        # 行わない（シート上フリーワード。アポインター担当者名の自動解決は表示側の将来対応）。
        { key: "appointer_code", label: "アポインター担当コード", target_table: "customer", target_column: "appointer_code", type: "text", required: true, max_length: 20 }
      ]
    },
    {
      name: "ご契約者情報",
      fields: [
        { key: "applicant_type", label: "ご契約者区分", target_table: "customer", target_column: "applicant_type", type: "select", option_group: "contractor_type", required: true },
        { key: "customer_name", label: "契約者名または法人名", target_table: "customer", target_column: "name", type: "text", required: true },
        { key: "customer_name_kana", label: "契約者名または法人名カナ", target_table: "customer", target_column: "contractor_name_kana", type: "text", required: true },
        { key: "representative_name", label: "代表者名（法人の場合必須）", target_table: "customer", target_column: "representative_name", type: "text" },
        { key: "representative_name_kana", label: "代表者名カナ（法人の場合必須）", target_table: "customer", target_column: "representative_name_kana", type: "text" },
        { key: "contact_name", label: "担当者名", target_table: "customer", target_column: "contact_name", type: "text", required: true },
        { key: "contact_name_kana", label: "担当者名カナ", target_table: "customer", target_column: "contact_name_kana", type: "text", required: true },
        { key: "contact_title", label: "担当者名役職", target_table: "customer", target_column: "contact_title", type: "text", required: true },
        { key: "contact2_name", label: "担当者名_2", target_table: "customer", target_column: "contact2_name", type: "text" },
        { key: "contact2_name_kana", label: "担当者名カナ_2", target_table: "customer", target_column: "contact2_name_kana", type: "text" },
        { key: "contact2_title", label: "担当者名役職_2", target_table: "customer", target_column: "contact2_title", type: "text" },
        { key: "customer_postal_code", label: "郵便番号", target_table: "customer", target_column: "postal_code", type: "text", required: true },
        { key: "customer_prefecture", label: "都道府県", target_table: "customer", target_column: "prefecture", type: "select", option_group: "prefecture", required: true },
        { key: "customer_city", label: "市区郡", target_table: "customer", target_column: "city", type: "text", required: true },
        { key: "customer_town", label: "町名", target_table: "customer", target_column: "town", type: "text", required: true },
        { key: "customer_address_detail", label: "番地・ビル・建物", target_table: "customer", target_column: "address_detail", type: "text", required: true },
        { key: "customer_phone", label: "固定電話番号", target_table: "customer", target_column: "phone", type: "text", required: true },
        { key: "customer_mobile", label: "携帯電話番号", target_table: "customer", target_column: "mobile_phone", type: "text", required: true },
        { key: "mobile_contact_person", label: "携帯担当者名", target_table: "customer", target_column: "mobile_contact_person", type: "text", required: true },
        { key: "capital", label: "資本金（法人の場合必須）", target_table: "order_work_detail", target_column: "capital", type: "text" }
      ]
    },
    {
      name: "店舗施設情報",
      fields: [
        { key: "store_name", label: "ご利用施設名称", target_table: "store", target_column: "store_name", type: "text", required: true },
        { key: "store_name_kana", label: "ご利用施設名称（フリガナ）", target_table: "store", target_column: "store_name_kana", type: "text", required: true },
        { key: "store_postal_code", label: "郵便番号", target_table: "store", target_column: "postal_code", type: "text", required: true },
        { key: "store_prefecture", label: "都道府県", target_table: "store", target_column: "prefecture", type: "select", option_group: "prefecture", required: true },
        { key: "store_city", label: "市区郡", target_table: "store", target_column: "city", type: "text", required: true },
        { key: "store_town", label: "町名", target_table: "store", target_column: "town", type: "text", required: true },
        { key: "store_address_detail", label: "番地・ビル・建物", target_table: "store", target_column: "address_detail", type: "text", required: true },
        { key: "store_phone", label: "店舗電話番号", target_table: "store", target_column: "phone_number", type: "text", required: true },
        { key: "business_hours_1", label: "営業時間1", target_table: "store", target_column: "business_hours_1", type: "text", required: true },
        { key: "business_hours_2", label: "営業時間2", target_table: "store", target_column: "business_hours_2", type: "text" },
        { key: "regular_holiday", label: "定休日", target_table: "store", target_column: "regular_holiday", type: "text", required: true },
        { key: "industry", label: "業種", target_table: "customer", target_column: "industry", type: "text", required: true },
        { key: "industry_sub", label: "業種（小区分）", target_table: "customer", target_column: "industry_sub", type: "text", required: true }
      ]
    },
    {
      name: "支払方法",
      fields: [
        { key: "payment_method", label: "お支払方法", target_table: "order", target_column: "payment_method", type: "select", option_group: "payment_method", required: true },
        { key: "invoice_destination", label: "請求書送付先住所", target_table: "customer", target_column: "invoice_destination", type: "select", option_group: "invoice_destination", required: true },
        { key: "invoice_name", label: "請求書送付先名", target_table: "customer", target_column: "invoice_name", type: "text", required: true },
        { key: "invoice_postal_code", label: "郵便番号", target_table: "customer", target_column: "invoice_postal_code", type: "text", required: true },
        { key: "invoice_address", label: "住所（都道府県・市区郡・町名・番地）", target_table: "customer", target_column: "invoice_address", type: "textarea", required: true, max_length: 500 },
        { key: "invoice_phone", label: "日中のご連絡先電話番号", target_table: "customer", target_column: "invoice_phone", type: "text", required: true },
        { key: "invoice_other_phone", label: "その他の電話番号", target_table: "customer", target_column: "invoice_other_phone", type: "text" },
        { key: "bundled_billing", label: "おまとめ請求", target_table: "order", target_column: "bundled_billing", type: "select", option_group: "bundled_billing" },
        { key: "bundle_target_order_number", label: "おまとめ先の案件番号", target_table: "order", target_column: "bundle_target_order_number", type: "text", max_length: 20 }
      ]
    },
    {
      name: "GBP登録情報",
      fields: [
        { key: "nearest_station", label: "最寄駅", target_table: "order_work_detail", target_column: "nearest_station", type: "text" },
        { key: "directions", label: "道順", target_table: "order_work_detail", target_column: "directions", type: "textarea", max_length: 500 },
        { key: "parking", label: "駐車場", target_table: "order_work_detail", target_column: "parking", type: "text", max_length: 20 },
        { key: "parking_capacity", label: "駐車可能な台数", target_table: "order_work_detail", target_column: "parking_capacity", type: "integer" },
        { key: "accepted_cards", label: "利用できるクレジットカードの種類", target_table: "order_work_detail", target_column: "accepted_cards", type: "text", max_length: 200 },
        { key: "opening_date", label: "開業日", target_table: "order_work_detail", target_column: "opening_date", type: "date", required: true },
        { key: "num_employees", label: "従業員数", target_table: "order_work_detail", target_column: "num_employees", type: "integer", required: true },
        { key: "gbp_url", label: "GoogleビジネスプロフィールURL", target_table: "order_work_detail", target_column: "gbp_url", type: "text", max_length: 500 },
        { key: "barrier_free", label: "バリアフリーの有無", target_table: "order_work_detail", target_column: "barrier_free", type: "select", option_group: "barrier_free" },
        { key: "wifi_available", label: "設備：Wi-Fiの有無", target_table: "order_work_detail", target_column: "wifi_available", type: "select", option_group: "wifi_available" },
        { key: "num_stores", label: "ご利用の店舗数", target_table: "order_work_detail", target_column: "num_stores", type: "integer" },
        { key: "business_account_name", label: "ビジネスアカウント名※GBP名称", target_table: "order_work_detail", target_column: "business_account_name", type: "text" },
        { key: "gbp_business_category", label: "GBPビジネスカテゴリー", target_table: "order_work_detail", target_column: "business_category_keyword", type: "text" },
        { key: "industry_keyword", label: "業種キーワード", target_table: "order_work_detail", target_column: "industry_keyword", type: "text" },
        { key: "reference_url", label: "お客様情報参考サイトURL", target_table: "order_work_detail", target_column: "reference_url", type: "text", max_length: 500 },
        { key: "business_type", label: "業態", target_table: "order_work_detail", target_column: "business_type", type: "select", option_group: "business_type", required: true },
        { key: "gbp_attribute_1", label: "属性1", target_table: "order_work_detail", target_column: "attribute_1", type: "checkbox_group", option_group: "gbp_attribute_1", max_length: 100 },
        { key: "gbp_attribute_2", label: "属性2", target_table: "order_work_detail", target_column: "attribute_2", type: "checkbox_group", option_group: "gbp_attribute_2", max_length: 100 },
        { key: "gbp_attribute_3", label: "属性3", target_table: "order_work_detail", target_column: "attribute_3", type: "checkbox_group", option_group: "gbp_attribute_3", max_length: 100 },
        { key: "gbp_attribute_4", label: "属性4", target_table: "order_work_detail", target_column: "attribute_4", type: "checkbox_group", option_group: "gbp_attribute_4", max_length: 100 },
        { key: "gbp_attribute_5", label: "属性5", target_table: "order_work_detail", target_column: "attribute_5", type: "checkbox_group", option_group: "gbp_attribute_5", max_length: 100 },
        { key: "gbp_attribute_6", label: "属性6", target_table: "order_work_detail", target_column: "attribute_6", type: "checkbox_group", option_group: "gbp_attribute_6", max_length: 100 },
        { key: "gbp_attribute_7", label: "属性7", target_table: "order_work_detail", target_column: "attribute_7", type: "checkbox_group", option_group: "gbp_attribute_7", max_length: 100 },
        { key: "gbp_attribute_8", label: "属性8", target_table: "order_work_detail", target_column: "attribute_8", type: "checkbox_group", option_group: "gbp_attribute_8", max_length: 100 },
        { key: "gbp_attribute_9", label: "属性9", target_table: "order_work_detail", target_column: "attribute_9", type: "checkbox_group", option_group: "gbp_attribute_9", max_length: 100 },
        { key: "gbp_attribute_10", label: "属性10", target_table: "order_work_detail", target_column: "attribute_10", type: "checkbox_group", option_group: "gbp_attribute_10", max_length: 100 },
        { key: "gbp_attribute_11", label: "属性11", target_table: "order_work_detail", target_column: "attribute_11", type: "checkbox_group", option_group: "gbp_attribute_11", max_length: 100 },
        { key: "lunch_hours", label: "ランチ", target_table: "order_work_detail", target_column: "lunch_hours", type: "text", max_length: 30 },
        { key: "dinner_hours", label: "ディナー", target_table: "order_work_detail", target_column: "dinner_hours", type: "text", max_length: 30 },
        { key: "available_from", label: "入店可能時間", target_table: "order_work_detail", target_column: "available_from", type: "text", max_length: 30 },
        { key: "order_time", label: "注文可能時間", target_table: "order_work_detail", target_column: "order_time", type: "text", max_length: 30 },
        { key: "gbp_multilingual", label: "GBPインバウンド多言語対策", target_table: "order", target_column: "gbp_multilingual", type: "select", option_group: "availability" },
        { key: "language_selection", label: "言語選択（多言語対策ありの場合必須）", target_table: "order", target_column: "language_selection", type: "select", option_group: "language" },
        { key: "keyword_prefecture", label: "キーワード_都道府県", target_table: "order_work_detail", target_column: "keyword_prefecture", type: "select", option_group: "prefecture", required: true },
        { key: "keyword_city", label: "キーワード_市町村", target_table: "order_work_detail", target_column: "keyword_city", type: "text", required: true, max_length: 50 },
        { key: "keyword_area_1", label: "キーワード_通称エリア名1", target_table: "order_work_detail", target_column: "keyword_area_1", type: "text", max_length: 50 },
        { key: "keyword_area_2", label: "キーワード_通称エリア名2", target_table: "order_work_detail", target_column: "keyword_area_2", type: "text", max_length: 50 },
        { key: "keyword_area_3", label: "キーワード_通称エリア名3", target_table: "order_work_detail", target_column: "keyword_area_3", type: "text", max_length: 50 },
        { key: "keyword_industry_main", label: "業種やサービス_メイン", target_table: "order_work_detail", target_column: "keyword_industry_main", type: "text", required: true, max_length: 50 },
        { key: "keyword_industry_sub1", label: "業種やサービス_サブ1", target_table: "order_work_detail", target_column: "keyword_industry_sub1", type: "text", max_length: 50 },
        { key: "keyword_industry_sub2", label: "業種やサービス_サブ2", target_table: "order_work_detail", target_column: "keyword_industry_sub2", type: "text", max_length: 50 },
        { key: "keyword_industry_sub3", label: "業種やサービス_サブ3", target_table: "order_work_detail", target_column: "keyword_industry_sub3", type: "text", max_length: 50 },
        { key: "keyword_industry_sub4", label: "業種やサービス_サブ4", target_table: "order_work_detail", target_column: "keyword_industry_sub4", type: "text", max_length: 50 },
        { key: "keyword_remarks", label: "キーワード備考（通称エリア設定理由など）", target_table: "order_work_detail", target_column: "keyword_remarks", type: "textarea" }
      ]
    },
    {
      name: "架電日時",
      fields: [
        { key: "contact_easy_time", label: "連絡が取りやすい時間帯", target_table: "order_work_detail", target_column: "contact_easy_time", type: "checkbox_group", option_group: "contact_time_slot", required: true, max_length: 100 },
        { key: "contact_easy_time_note", label: "連絡が取りやすい時間帯【その他】", target_table: "order_work_detail", target_column: "contact_easy_time_note", type: "text", max_length: 200 },
        { key: "contact_easy_day", label: "連絡が取りやすい曜日", target_table: "order_work_detail", target_column: "contact_easy_day", type: "checkbox_group", option_group: "contact_day", required: true, max_length: 100 },
        { key: "contact_easy_day_note", label: "連絡が取りやすい曜日【その他】", target_table: "order_work_detail", target_column: "contact_easy_day_note", type: "text", max_length: 200 }
      ]
    },
    {
      name: "アカウント情報",
      fields: [
        { key: "has_google_business", label: "Googleビジネスアカウントの所持状況", target_table: "order_work_detail", target_column: "has_google_business", type: "select", option_group: "gbp_possession", required: true },
        { key: "gbp_owner_permission", label: "オーナー権限（所持ありの場合必須）", target_table: "order_work_detail", target_column: "gbp_owner_permission", type: "select", option_group: "permission_known" },
        { key: "gbp_owner_name", label: "オーナー権限所有者名・担当者名", target_table: "order_work_detail", target_column: "gbp_owner_name", type: "text" },
        { key: "gbp_owner_contact", label: "オーナー権限所有者・担当者連絡先", target_table: "order_work_detail", target_column: "gbp_owner_contact", type: "text" },
        { key: "gbp_permission", label: "弊社へのGBP権限付与状況", target_table: "order_work_detail", target_column: "gbp_permission", type: "select", option_group: "gbp_grant_status", required: true },
        { key: "has_facebook", label: "Facebookアカウントの所持", target_table: "order_work_detail", target_column: "has_facebook", type: "select", option_group: "sns_possession", required: true },
        { key: "has_facebook_page", label: "Facebookページの所持", target_table: "order_work_detail", target_column: "has_facebook_page", type: "select", option_group: "sns_possession", required: true },
        { key: "facebook_id", label: "FacebookID（保有している場合必須）", target_table: "order_work_detail", target_column: "facebook_id", type: "text" },
        { key: "facebook_pass", label: "FacebookPASS（保有している場合必須）", target_table: "order_work_detail", target_column: "facebook_pass", type: "text" },
        { key: "instagram_id", label: "InstagramID", target_table: "order_work_detail", target_column: "instagram_id", type: "text", required: true },
        { key: "instagram_pass", label: "Instagramパスワード", target_table: "order_work_detail", target_column: "instagram_pass", type: "text", required: true },
        { key: "has_line", label: "LINEアカウントの所持", target_table: "order_work_detail", target_column: "has_line", type: "select", option_group: "sns_possession", required: true },
        { key: "system_account_pass", label: "システムアカウントPASS（半角16桁まで）", target_table: "order_work_detail", target_column: "system_account_pass", type: "text", required: true, max_length: 16 },
        { key: "order_remarks", label: "備考", target_table: "order", target_column: "remarks", type: "textarea" }
      ]
    },
    {
      # P11（最終確認画面）の入力項目のみ。重説レ点・電子署名・申込完了はステップ外（ヘッダコメント参照）。
      name: "最終確認",
      fields: [
        { key: "consent_rep_age", label: "同意時代表者年齢", target_table: "order", target_column: "consent_rep_age", type: "integer" },
        { key: "consent_contact_age", label: "同意時担当者年齢", target_table: "order", target_column: "consent_contact_age", type: "integer" }
      ]
    }
  ].freeze

  # 選択肢の出所がマスタであるキー（毎回同期。BridgePlusFormTemplateSeederと同パターン）。
  # product_initial_fee は AILINK 商材の ProductInitialFee から複製する。
  MASTER_DERIVED_OPTION_GROUPS = %w[payment_method product_initial_fee].freeze

  def self.call
    new.call
  end

  def call
    seed_product_masters
    seed_option_groups
    seed_form_template
  end

  private

  # 商材・初期費用は db/seeds/products.rb にも同一定義があるが、シーダー単体（spec・運用時の再実行）でも
  # 初期費用プルダウンの選択肢を組み立てられるよう、ここでも冪等に確保する。
  def seed_product_masters
    @product = Product.find_or_create_by!(code: PRODUCT_CODE) do |p|
      p.name = "AILINK"
      p.description = "AILINK 商材（MEO対策サービス・Brige_plusプラン）"
      p.is_active = true
    end

    INITIAL_FEES.each do |name, amount, sort_order|
      ProductInitialFee.find_or_create_by!(product: @product, amount: amount) do |fee|
        fee.name = name
        fee.sort_order = sort_order
        fee.is_active = true
      end
    end
  end

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
    template = FormTemplate.find_or_create_by!(product: @product) do |t|
      t.name = "AILINK 申込フォーム"
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

    if field.persisted?
      sync_master_derived_choices(field, field_def)
      return
    end

    field.label = field_def[:label]
    field.field_type = field_def[:type]
    field.target_table = field_def[:target_table]
    field.target_column = field_def[:target_column]
    field.required = field_def.fetch(:required, false)
    field.sort_order = index + 1
    field.editable_by_tier = [ "sales_representative" ]
    field.input_options = choices_for(field_def[:option_group])
    field.validation_rules = field_def[:max_length] ? { "max_length" => field_def[:max_length] } : {}
    field.save!
  end

  def sync_master_derived_choices(field, field_def)
    option_group_key = field_def[:option_group]
    return unless MASTER_DERIVED_OPTION_GROUPS.include?(option_group_key)

    expected = choices_for(option_group_key)
    return if field.input_options == expected

    field.update!(input_options: expected)
    Rails.logger.info("AilinkFormTemplateSeeder: #{field.field_key} の選択肢をマスタから再同期しました")
  end

  def choices_for(option_group_key)
    return {} if option_group_key.blank?

    # マスタ由来の選択肢（master-data-design-policy.md §5-3 と同じ扱い）。
    return { "choices" => PaymentMethod.ordered.active.pluck(:code, :label) } if option_group_key == "payment_method"
    if option_group_key == "product_initial_fee"
      return { "choices" => @product.product_initial_fees.active.order(:sort_order).pluck(:id, :name).map { |id, name| [ id.to_s, name ] } }
    end

    { "choices" => OPTION_GROUPS.fetch(option_group_key).fetch(:values) }
  end
end
