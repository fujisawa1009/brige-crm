# AILINK商材の申込フォーム（浅賀確認用_選択フォーム要件整理.xlsx・2026-08-21 CEO指示）で
# 必要になった、既存スキーマに保存先が無い3項目を追加する。
# - orders.discount_option: P2 オプション②（割引なし／長期割引（税込11,000円）／長期割引（税込22,000円））。
#   Q-46（CEO決定 2026-08-19: 割引A/B別の利用規約自動切替を実装する）がR5で参照する選択値の保存先。
# - order_work_details.has_facebook_page: P9「Facebookページの所持」（既存 has_facebook は
#   「Facebookアカウントの所持」でありページ所持とは別項目）。
# - order_work_details.has_line: P9「LINEアカウントの所持」。
class AddAilinkFormColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :discount_option, :string, limit: 50
    add_column :order_work_details, :has_facebook_page, :string, limit: 20
    add_column :order_work_details, :has_line, :string, limit: 20
  end
end
