# admin/customers の申込ステータスバッジ。R6-2でtag.spanを返す形に統一
# （呼び出し側は<span class="...">でラップせず、この戻り値をそのまま埋め込む）。
module Admin::CustomersHelper
  def customer_status_badge_color(code)
    case code
    when CustomerStatus::CODE_APPLIED then "blue"
    when "contracted" then "green"
    when "withdrawn" then "slate-muted"
    when "returned", "needs_correction", "needs_reconfirmation" then "amber"
    else "slate"
    end
  end

  def customer_status_badge(code)
    badge_tag(customer_status_label(code), color: customer_status_badge_color(code))
  end
end
