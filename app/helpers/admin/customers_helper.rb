# admin/customers の申込ステータスバッジ配色。
module Admin::CustomersHelper
  def customer_status_badge_class(code)
    case code
    when CustomerStatus::CODE_APPLIED then "bg-blue-100 text-blue-700"
    when "contracted" then "bg-green-100 text-green-700"
    when "withdrawn" then "bg-slate-100 text-slate-500"
    when "returned", "needs_correction", "needs_reconfirmation" then "bg-amber-100 text-amber-700"
    else "bg-slate-100 text-slate-600"
    end
  end
end
