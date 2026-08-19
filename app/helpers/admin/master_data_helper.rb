# 商材・プラン・初期費用・商材オプション・選択肢グループ/値など、is_activeフラグを持つ
# マスタ系画面で共通の有効/無効バッジ。
module Admin::MasterDataHelper
  def active_badge(active)
    if active
      content_tag :span, "有効", class: "rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700"
    else
      content_tag :span, "無効", class: "rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500"
    end
  end
end
