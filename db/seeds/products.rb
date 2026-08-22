# 商材・プラン・初期費用・商材オプションの実マスタ（Laravel ProductSeeder 移植）。
# 移植元: boilerplate-vue-env/laravel/database/seeders/ProductSeeder.php
# find_or_create_by! による冪等実行（bin/rails db:seed を繰り返しても増殖しない）。

# --- 商材 -------------------------------------------------------------------
bridge_plus = Product.find_or_create_by!(code: "BRIDGE_PLUS") do |p|
  p.name = "BridgePlus"
  p.description = "BridgePlus 商材（MEO対策サービス）"
  p.is_active = true
end

bridge = Product.find_or_create_by!(code: "BRIDGE") do |p|
  p.name = "Bridge"
  p.description = "Bridge 商材（MEO対策サービス・Bridge版）"
  p.is_active = true
end

# --- BridgePlus プラン（A〜F） ------------------------------------------------
[
  [ "Aプラン", "BP-A", 39_800, 1 ],
  [ "Bプラン", "BP-B", 34_800, 2 ],
  [ "Cプラン", "BP-C", 29_800, 3 ],
  [ "Dプラン", "BP-D", 24_800, 4 ],
  [ "Eプラン", "BP-E", 19_800, 5 ],
  [ "Fプラン", "BP-F", 14_800, 6 ]
].each do |name, code, monthly_fee, sort_order|
  Plan.find_or_create_by!(product: bridge_plus, code: code) do |plan|
    plan.name = name
    plan.monthly_fee = monthly_fee
    plan.sort_order = sort_order
    plan.is_active = true
  end
end

# --- BridgePlus 初期費用 ------------------------------------------------------
[
  [ "0円", 0, 1 ],
  [ "30,000円", 30_000, 2 ],
  [ "50,000円", 50_000, 3 ],
  [ "100,000円", 100_000, 4 ],
  [ "150,000円", 150_000, 5 ]
].each do |name, amount, sort_order|
  ProductInitialFee.find_or_create_by!(product: bridge_plus, amount: amount) do |fee|
    fee.name = name
    fee.sort_order = sort_order
    fee.is_active = true
  end
end

# --- BridgePlus 商材オプション ------------------------------------------------
[
  [ "MEOサービス", 1 ],
  [ "MEO外部リンク", 2 ],
  [ "サイテーション", 3 ]
].each do |name, sort_order|
  ProductOption.find_or_create_by!(product: bridge_plus, name: name) do |opt|
    opt.sort_order = sort_order
    opt.is_active = true
  end
end

# --- Bridge プラン ------------------------------------------------------------
[
  # Linksα12
  [ "Linksα12(スタートアップ)", "BR-LA12-STU", 14_800, 1 ],
  [ "Linksα12(ノーマル)", "BR-LA12-NRM", 19_800, 2 ],
  [ "Linksα12(カスタマイズ)", "BR-LA12-CST", 29_800, 3 ],
  [ "Linksα12(ベーシック)", "BR-LA12-BSC", 9_800, 4 ],
  # Linksα6
  [ "Linksα6(カスタマイズ)", "BR-LA6-CST", 29_800, 5 ],
  [ "Linksα6(スタートアップ)", "BR-LA6-STU", 14_800, 6 ],
  [ "Linksα6(ノーマル)", "BR-LA6-NRM", 19_800, 7 ],
  [ "Linksα6(ベーシック)", "BR-LA6-BSC", 9_800, 8 ],
  # MEO単体[12]
  [ "MEO単体[12]", "BR-MEO-12", 10_000, 9 ],
  [ "MEO単体（10%割引）[12]", "BR-MEO-12-10", 9_000, 10 ],
  [ "MEO単体（20%割引）[12]", "BR-MEO-12-20", 8_000, 11 ],
  [ "MEO単体（30%割引）[12]", "BR-MEO-12-30", 7_000, 12 ],
  [ "MEO単体（40%割引）[12]", "BR-MEO-12-40", 6_000, 13 ],
  # シンプル+MEOセット[12]
  [ "シンプル+MEOセット[12]", "BR-SIM-MEO-12", 22_980, 14 ],
  [ "シンプル+MEOセット[12](10%割引)", "BR-SIM-MEO-12-10", 20_680, 15 ],
  [ "シンプル+MEOセット[12](20%割引)", "BR-SIM-MEO-12-20", 18_380, 16 ],
  [ "シンプル+MEOセット[12](30%割引)", "BR-SIM-MEO-12-30", 16_080, 17 ],
  [ "シンプル+MEOセット[12](40%割引)", "BR-SIM-MEO-12-40", 13_780, 18 ],
  # シンプル+MEOセット[24]
  [ "シンプル+MEOセット[24]", "BR-SIM-MEO-24", 22_980, 19 ],
  [ "シンプル+MEOセット[24](10%割引)", "BR-SIM-MEO-24-10", 20_680, 20 ],
  [ "シンプル+MEOセット[24](20%割引)", "BR-SIM-MEO-24-20", 18_380, 21 ],
  [ "シンプル+MEOセット[24](30%割引)", "BR-SIM-MEO-24-30", 16_080, 22 ],
  [ "シンプル+MEOセット[24](40%割引)", "BR-SIM-MEO-24-40", 13_780, 23 ],
  # スタートアップ+MEOセット[12]
  [ "スタートアップ+MEOセット[12]", "BR-STU-MEO-12", 24_800, 24 ],
  [ "スタートアップ+MEOセット[12](10%割引)", "BR-STU-MEO-12-10", 22_320, 25 ],
  [ "スタートアップ+MEOセット[12](20%割引)", "BR-STU-MEO-12-20", 19_840, 26 ],
  [ "スタートアップ+MEOセット[12](30%割引)", "BR-STU-MEO-12-30", 17_360, 27 ],
  [ "スタートアップ+MEOセット[12](40%割引)", "BR-STU-MEO-12-40", 14_880, 28 ],
  # スタートアップ+MEOセット[24]
  [ "スタートアップ+MEOセット[24]", "BR-STU-MEO-24", 24_800, 29 ],
  [ "スタートアップ+MEOセット[24](10%割引)", "BR-STU-MEO-24-10", 22_320, 30 ],
  [ "スタートアップ+MEOセット[24](20%割引)", "BR-STU-MEO-24-20", 19_840, 31 ],
  [ "スタートアップ+MEOセット[24](30%割引)", "BR-STU-MEO-24-30", 17_360, 32 ],
  [ "スタートアップ+MEOセット[24](40%割引)", "BR-STU-MEO-24-40", 14_880, 33 ],
  # スタートアッププラン[12]
  [ "スタートアッププラン[12]", "BR-STU-12", 14_800, 34 ],
  [ "スタートアッププラン[12](10%割引)", "BR-STU-12-10", 13_320, 35 ],
  [ "スタートアッププラン[12](20%割引)", "BR-STU-12-20", 11_840, 36 ],
  [ "スタートアッププラン[12](30%割引)", "BR-STU-12-30", 10_360, 37 ],
  [ "スタートアッププラン[12](40%割引)", "BR-STU-12-40", 8_880, 38 ],
  # スタートアッププラン[24]
  [ "スタートアッププラン[24]", "BR-STU-24", 14_800, 39 ],
  [ "スタートアッププラン[24](10%割引)", "BR-STU-24-10", 13_320, 40 ],
  [ "スタートアッププラン[24](20%割引)", "BR-STU-24-20", 11_840, 41 ],
  [ "スタートアッププラン[24](30%割引)", "BR-STU-24-30", 10_360, 42 ],
  [ "スタートアッププラン[24](40%割引)", "BR-STU-24-40", 8_880, 43 ],
  # MEO単体[24]（月額なし）
  [ "MEO単体[24]", "BR-MEO-24", nil, 44 ],
  [ "MEO単体（10%割引）[24]", "BR-MEO-24-10", nil, 45 ],
  [ "MEO単体（20%割引）[24]", "BR-MEO-24-20", nil, 46 ],
  [ "MEO単体（30%割引）[24]", "BR-MEO-24-30", nil, 47 ],
  [ "MEO単体（40%割引）[24]", "BR-MEO-24-40", nil, 48 ]
].each do |name, code, monthly_fee, sort_order|
  Plan.find_or_create_by!(product: bridge, code: code) do |plan|
    plan.name = name
    plan.monthly_fee = monthly_fee
    plan.sort_order = sort_order
    plan.is_active = true
  end
end

# --- AILINK 商材（2026-08-21 CEO指示・浅賀確認用_選択フォーム要件整理.xlsx） -------------------
# 商材=AILINK／プラン=Brige_plus（1価格固定・P2「プラン: 自動入力」）と解釈（名称は要CEO確認）。
# 月額は要件シートに未提示のため未設定（nil）。確定後にこの値を更新すること。
ailink = Product.find_or_create_by!(code: "AILINK") do |p|
  p.name = "AILINK"
  p.description = "AILINK 商材（MEO対策サービス・Brige_plusプラン）"
  p.is_active = true
end

Plan.find_or_create_by!(product: ailink, code: "AILINK-BRIGE-PLUS") do |plan|
  plan.name = "Brige_plus"
  plan.monthly_fee = nil # 【要確認】1価格固定の月額が要件シート未提示
  plan.sort_order = 1
  plan.is_active = true
end

# 初期費用（P2。BRIDGE_PLUSと同一の5値・0円は代理店負担）
[
  [ "0円", 0, 1 ],
  [ "30,000円", 30_000, 2 ],
  [ "50,000円", 50_000, 3 ],
  [ "100,000円", 100_000, 4 ],
  [ "150,000円", 150_000, 5 ]
].each do |name, amount, sort_order|
  ProductInitialFee.find_or_create_by!(product: ailink, amount: amount) do |fee|
    fee.name = name
    fee.sort_order = sort_order
    fee.is_active = true
  end
end

# 商材オプション（P2 オプション①。デフォルトチェック＝申込フォームの必須チェック群）
[
  [ "MEOサービス", 1 ],
  [ "MEO外部リンク", 2 ],
  [ "サイテーション", 3 ]
].each do |name, sort_order|
  ProductOption.find_or_create_by!(product: ailink, name: name) do |opt|
    opt.sort_order = sort_order
    opt.is_active = true
  end
end

puts "products seed: products=#{Product.count} plans=#{Plan.count} initial_fees=#{ProductInitialFee.count} options=#{ProductOption.count}"
