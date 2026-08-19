# 商材・プラン・初期費用・商材オプション・選択肢グループ/値など、is_activeフラグを持つ
# マスタ系画面で共通の有効/無効バッジ。
module Admin::MasterDataHelper
  def active_badge(active)
    active ? badge_tag("有効", color: "green") : badge_tag("無効", color: "slate-muted")
  end
end
