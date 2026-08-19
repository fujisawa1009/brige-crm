# admin/orders の案件ステータス表示（日本語ラベル・バッジ配色）。ラベル変換はcustomers/show等
# 他コントローラのビューからも参照するため（案件のミニ一覧に表示）、controller#helper_methodではなく
# 全ビューに自動includeされるモジュールヘルパーとして定義する。
module Admin::OrdersHelper
  # Order#statusはOrderStatus.code（"0:受注"等の記号混じりコード）を持つのみで表示ラベルを
  # 持たないため、日本語ラベルに変換する。@order_status_labelsはビュー単位でメモ化される
  # （helperモジュールはActionViewインスタンスにmix-inされるため、行数分のN+1にならない）。
  def order_status_label(code)
    @order_status_labels ||= OrderStatus.pluck(:code, :label).to_h
    @order_status_labels.fetch(code, code)
  end

  def order_status_badge_class(code)
    case code
    when OrderStatus::CODE_ORDERED then "bg-blue-100 text-blue-700"
    when "10:作業進行中" then "bg-amber-100 text-amber-700"
    when "21:解約", "22:強制解約" then "bg-red-100 text-red-700"
    when "100:CLOSE" then "bg-green-100 text-green-700"
    else "bg-slate-100 text-slate-600"
    end
  end
end
